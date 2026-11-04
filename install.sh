#!/usr/bin/env bash
# terminal-config 一键安装/卸载脚本
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
用法: $0 [install|uninstall]

  install      安装检测到的工具对应的配置（默认）
  uninstall    卸载本脚本安装的配置

安装前会检查 Ghostty、Starship、Vim 是否存在，只安装存在的工具配置。
EOF
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

do_install() {
  if [ -f "$STATE_FILE" ]; then
    warn "检测到已有安装记录：$STATE_FILE"
    warn "请先执行 $0 --uninstall，再重新安装。"
    exit 1
  fi

  mkdir -p "$STATE_DIR"
  : > "$STATE_FILE"
  local installed=0

  if has_ghostty; then
    install_copy "$ROOT_DIR/ghostty/config" "$CONFIG_HOME/ghostty/config" "ghostty-config" "Ghostty"
    installed=1
  else
    warn "未检测到 Ghostty，跳过 ghostty/config"
  fi

  if command -v starship >/dev/null 2>&1; then
    install_copy "$ROOT_DIR/starship/starship.toml" "$CONFIG_HOME/starship.toml" "starship.toml" "Starship"
    installed=1
  else
    warn "未检测到 Starship，跳过 starship/starship.toml"
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

  success "安装完成。卸载请执行：$0 --uninstall"
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
        if [ -z "${backup:-}" ] && [ -f "$target" ] && [ ! -s "$target" ]; then
          rm -f "$target"
        fi
        success "已从 $target 移除 Vim 配置"
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
  uninstall|--uninstall|-u) do_uninstall ;;
  -h|--help|help) usage ;;
  *)
    error "未知参数：$1"
    usage
    exit 1
    ;;
esac
