#!/usr/bin/env bash
# terminal-config 一键安装/卸载脚本
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
  ROOT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
else
  ROOT_DIR="$(pwd)"
fi
REPO_SLUG="sky-stroller/terminal-config"
REPO_BRANCH="main"
TMP_DIR=""

cleanup() {
  if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$CONFIG_HOME/terminal-config"
STATE_FILE="$STATE_DIR/state"
BACKUP_DIR="$STATE_DIR/backup-$(date +%Y%m%d%H%M%S)"

if [ -t 1 ]; then
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  NC=$'\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
fi

info() { printf '%s\n' "${BLUE}==>${NC} $*"; }
success() { printf '%s\n' "${GREEN}✓${NC} $*"; }
warn() { printf '%s\n' "${YELLOW}!${NC} $*"; }
error() { printf '%s\n' "${RED}✗${NC} $*" >&2; }

usage() {
  cat <<EOF
用法: $0 [install|uninstall|register-fonts]

  install      安装检测到的工具对应的配置（默认）
  uninstall    卸载本脚本安装的配置
  register-fonts  仅注册已有字体，不修改工具配置（macOS）

安装前会检查 Ghostty 和 Vim 是否存在，只安装检测到的工具配置。
Starship 缺失时会优先通过 Homebrew 自动安装。
macOS 会注册 ~/Library/Fonts 中已有的 Maple Mono NF CN 字体（需要 Python 3）。

远程安装：
  curl -fsSL https://raw.githubusercontent.com/sky-stroller/terminal-config/main/install.sh | bash
EOF
}

prepare_root() {
  if [ -f "$ROOT_DIR/ghostty/config" ] && [ -f "$ROOT_DIR/starship/starship.toml" ] && [ -f "$ROOT_DIR/vim/cursor.vim" ]; then
    return 0
  fi

  command -v curl >/dev/null 2>&1 || {
    error "未找到 curl，无法远程下载配置"
    exit 1
  }
  command -v tar >/dev/null 2>&1 || {
    error "未找到 tar，无法解压配置"
    exit 1
  }

  info "未检测到本地配置文件，正在从 GitHub 下载..."
  TMP_DIR="$(mktemp -d)"
  if ! curl -fsSL "https://github.com/$REPO_SLUG/archive/refs/heads/$REPO_BRANCH.tar.gz" | tar -xz -C "$TMP_DIR" --strip-components=1; then
    error "下载配置失败，请检查网络或仓库地址"
    exit 1
  fi
  ROOT_DIR="$TMP_DIR"

  if [ ! -f "$ROOT_DIR/ghostty/config" ] || [ ! -f "$ROOT_DIR/starship/starship.toml" ] || [ ! -f "$ROOT_DIR/vim/cursor.vim" ]; then
    error "下载的配置不完整"
    exit 1
  fi
  success "配置下载完成"
}

has_ghostty() {
  command -v ghostty >/dev/null 2>&1 && return 0
  [ -d "/Applications/Ghostty.app" ] && return 0
  [ -d "$HOME/Applications/Ghostty.app" ] && return 0
  return 1
}

backup_target() {
  local target="$1"
  local name="$2"
  if [ -e "$target" ]; then
    mkdir -p "$BACKUP_DIR"
    cp -p "$target" "$BACKUP_DIR/$name"
    printf '%s' "$BACKUP_DIR/$name"
  fi
}

record() {
  printf '%s|%s|%s\n' "$1" "$2" "$3" >> "$STATE_FILE"
}

install_copy() {
  local source="$1"
  local target="$2"
  local name="$3"
  local label="$4"

  if [ ! -f "$source" ]; then
    error "缺少配置文件：$source"
    return 1
  fi

  mkdir -p "$(dirname "$target")"
  local backup
  backup="$(backup_target "$target" "$name")"
  cp "$source" "$target"
  record "copy" "$target" "$backup"
  success "$label 已安装到 $target"
}

remove_vim_block() {
  local file="$1"
  [ -f "$file" ] || return 0
  awk '
    /^" >>> terminal-config >>>$/ { skip=1; next }
    /^" <<< terminal-config <<<$/ { skip=0; next }
    !skip { print }
  ' "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
}

remove_zsh_block() {
  local file="$1"
  [ -f "$file" ] || return 0
  awk '
    /^# >>> terminal-config >>>$/ { skip=1; next }
    /^# <<< terminal-config <<<$/ { skip=0; next }
    !skip { print }
  ' "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
}

install_vim() {
  local source="$ROOT_DIR/vim/cursor.vim"
  local target="$HOME/.vimrc"

  if [ ! -f "$source" ]; then
    error "缺少配置文件：$source"
    return 1
  fi

  if grep -q '^let &t_SR = ' "$target" 2>/dev/null && ! grep -q '^" >>> terminal-config >>>' "$target" 2>/dev/null; then
    warn "$target 已包含光标配置但没有 terminal-config 标记，跳过 Vim 配置以避免重复。"
    warn "如需由脚本管理，请先移除旧的 t_SI / t_EI / t_SR 配置。"
    return 0
  fi

  local backup
  backup="$(backup_target "$target" "vimrc")"
  touch "$target"
  remove_vim_block "$target"
  {
    printf '\n" >>> terminal-config >>>\n'
    cat "$source"
    printf '" <<< terminal-config <<<\n'
  } >> "$target"
  record "vim" "$target" "$backup"
  success "Vim 光标配置已追加到 $target"
}

install_starship() {
  if command -v starship >/dev/null 2>&1; then
    success "Starship 已安装：$(command -v starship)"
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    info "未检测到 Starship，正在通过 Homebrew 安装..."
    if ! brew install starship; then
      error "Homebrew 安装 Starship 失败"
      return 1
    fi
  else
    warn "未检测到 Homebrew，使用 Starship 官方安装脚本..."
    if ! curl -fsSL https://starship.rs/install.sh | sh -s -- -y; then
      error "Starship 官方安装脚本执行失败"
      return 1
    fi
  fi

  if command -v starship >/dev/null 2>&1; then
    success "Starship 安装完成：$(command -v starship)"
  else
    warn "Starship 已安装，但当前 PATH 中找不到，请重新打开终端"
  fi
  return 0
}

register_maple_fonts() {
  [ "$(uname -s)" = "Darwin" ] || return 0

  local font_files=("$HOME"/Library/Fonts/MapleMono-NF-CN-*.ttf)
  if [ ! -f "${font_files[0]}" ]; then
    warn "未找到 Maple Mono NF CN 字体，请先用字体簿安装或执行 brew install --cask font-maple-mono-nf-cn"
    return 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    warn "未找到 Python 3，跳过字体注册；请在字体簿中安装 Maple Mono NF CN"
    return 0
  fi

  info "正在向 macOS 当前用户字体库注册 Maple Mono NF CN..."
  if python3 - "${font_files[@]}" <<'PY'
import ctypes
import os
import sys

cf = ctypes.CDLL('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
ct = ctypes.CDLL('/System/Library/Frameworks/CoreText.framework/CoreText')
cf.CFURLCreateFromFileSystemRepresentation.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_long, ctypes.c_bool]
cf.CFURLCreateFromFileSystemRepresentation.restype = ctypes.c_void_p
cf.CFErrorGetCode.argtypes = [ctypes.c_void_p]
cf.CFErrorGetCode.restype = ctypes.c_long
cf.CFErrorCopyDescription.argtypes = [ctypes.c_void_p]
cf.CFErrorCopyDescription.restype = ctypes.c_void_p
cf.CFStringGetCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_long, ctypes.c_uint]
cf.CFRelease.argtypes = [ctypes.c_void_p]
ct.CTFontManagerRegisterFontsForURL.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.POINTER(ctypes.c_void_p)]
ct.CTFontManagerRegisterFontsForURL.restype = ctypes.c_bool

failed = False
for path in sys.argv[1:]:
    data = os.fsencode(path)
    url = cf.CFURLCreateFromFileSystemRepresentation(None, data, len(data), False)
    if not url:
        print(f'无法创建字体 URL：{path}', file=sys.stderr)
        failed = True
        continue
    error = ctypes.c_void_p()
    # 使用当前用户的持久注册范围；105 表示字体已经注册。
    ok = ct.CTFontManagerRegisterFontsForURL(url, 2, ctypes.byref(error))
    cf.CFRelease(url)
    already_registered = bool(error.value) and cf.CFErrorGetCode(error) == 105
    if not ok and not already_registered:
        failed = True
        message = '未知错误'
        if error.value:
            description = cf.CFErrorCopyDescription(error)
            if description:
                buffer = ctypes.create_string_buffer(2048)
                if cf.CFStringGetCString(description, buffer, len(buffer), 0x08000100):
                    message = buffer.value.decode('utf-8', errors='replace')
                cf.CFRelease(description)
        print(f'字体注册失败：{path}：{message}', file=sys.stderr)
    if error.value:
        cf.CFRelease(error)
sys.exit(1 if failed else 0)
PY
  then
    success "Maple Mono NF CN 字体已注册，请重载 VS Code 窗口或重启终端应用"
  else
    warn "部分字体未能注册，请在字体簿中检查并安装；继续安装工具配置"
  fi
}

install_zshrc() {
  local target="$HOME/.zshrc"

  if [ "${SHELL##*/}" != "zsh" ]; then
    warn "当前 shell 不是 zsh，跳过 ~/.zshrc 配置"
    return 0
  fi

  if grep -q 'starship init zsh' "$target" 2>/dev/null; then
    if grep -q '^# >>> terminal-config >>>' "$target" 2>/dev/null; then
      success "~/.zshrc 已包含 Starship 初始化"
    else
      warn "~/.zshrc 已包含 starship init zsh，跳过自动写入"
    fi
    return 0
  fi

  local backup
  backup="$(backup_target "$target" "zshrc")"
  touch "$target"
  remove_zsh_block "$target"
  {
    printf '\n# >>> terminal-config >>>\n'
    printf 'eval "$(starship init zsh)"\n'
    printf '# <<< terminal-config <<<\n'
  } >> "$target"
  record "zsh" "$target" "$backup"
  success "Starship 初始化已写入 $target"
}

do_install() {
  prepare_root

  if [ -f "$STATE_FILE" ]; then
    warn "检测到已有安装记录：$STATE_FILE"
    warn "请先执行 $0 --uninstall，再重新安装。"
    exit 1
  fi

  register_maple_fonts

  mkdir -p "$STATE_DIR"
  : > "$STATE_FILE"
  local installed=0

  if has_ghostty; then
    install_copy "$ROOT_DIR/ghostty/config" "$CONFIG_HOME/ghostty/config" "ghostty-config" "Ghostty"
    installed=1
  else
    warn "未检测到 Ghostty，跳过 ghostty/config"
  fi

  if install_starship; then
    install_copy "$ROOT_DIR/starship/starship.toml" "$CONFIG_HOME/starship.toml" "starship.toml" "Starship"
    install_zshrc
    installed=1
  else
    warn "Starship 安装失败，跳过 starship/starship.toml"
  fi

  if command -v vim >/dev/null 2>&1; then
    install_vim
    installed=1
  else
    warn "未检测到 Vim，跳过 vim/cursor.vim"
  fi

  if [ "$installed" -eq 0 ]; then
    warn "未检测到任何目标工具，未安装配置。"
    rm -rf "$STATE_DIR"
    return 1
  fi

  if [ -n "${TMP_DIR:-}" ]; then
    success "安装完成。卸载请执行：curl -fsSL https://raw.githubusercontent.com/$REPO_SLUG/$REPO_BRANCH/install.sh | bash -s -- --uninstall"
  else
    success "安装完成。卸载请执行：$0 --uninstall"
  fi
}

do_uninstall() {
  if [ ! -f "$STATE_FILE" ]; then
    warn "未找到安装记录，可能尚未安装。"
    return 0
  fi

  local mode target backup
  while IFS='|' read -r mode target backup; do
    [ -n "${mode:-}" ] || continue
    case "$mode" in
      copy)
        if [ -n "${backup:-}" ] && [ -f "$backup" ]; then
          cp -p "$backup" "$target"
          success "已恢复 $target"
        else
          rm -f "$target"
          success "已删除 $target"
        fi
        ;;
      vim)
        remove_vim_block "$target"
        if [ -z "${backup:-}" ] && [ -f "$target" ] && ! grep -q '[^[:space:]]' "$target"; then
          rm -f "$target"
        fi
        success "已从 $target 移除 Vim 配置"
        ;;
      zsh)
        remove_zsh_block "$target"
        if [ -z "${backup:-}" ] && [ -f "$target" ] && ! grep -q '[^[:space:]]' "$target"; then
          rm -f "$target"
        fi
        success "已从 $target 移除 Starship 初始化"
        ;;
      *)
        warn "未知记录类型：$mode"
        ;;
    esac
  done < "$STATE_FILE"

  rm -rf "$STATE_DIR"
  success "卸载完成"
}

case "${1:-install}" in
  install) do_install ;;
  register-fonts|--register-fonts) register_maple_fonts ;;
  uninstall|--uninstall|-u) do_uninstall ;;
  -h|--help|help) usage ;;
  *)
    error "未知参数：$1"
    usage
    exit 1
    ;;
esac
