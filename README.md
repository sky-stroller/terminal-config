# terminal-config

一套基于 Catppuccin Mocha 的终端配置，统一 Ghostty、Starship 和 Vim 的外观与光标行为。

## 包含内容

| 文件 | 作用 |
|------|------|
| `ghostty/config` | Ghostty 终端：字体、主题、窗口、光标、交互 |
| `starship/starship.toml` | Starship 提示符：Catppuccin 彩虹条布局 |
| `vim/cursor.vim` | Vim 光标形状：插入、普通、替换模式分别使用不同光标 |
| `install.sh` | 一键安装/卸载脚本 |

```text
terminal-config/
├── ghostty/
│   └── config
├── starship/
│   └── starship.toml
├── vim/
│   └── cursor.vim
├── install.sh
└── README.md
```

## 依赖

- [Ghostty](https://ghostty.org/) 1.4+
- [Starship](https://starship.rs/) 1.27+（见下方“Starship 安装”）
- `Maple Mono NF CN` 字体（见下方“字体安装”）
- 支持 Nerd Font 图标的终端字体

## 字体安装

配置默认使用 `Maple Mono NF CN`，它包含 Nerd Font 图标以及中文/日文字形。

macOS 推荐用 Homebrew 安装：

```bash
brew install --cask font-maple-mono-nf-cn
```

如果不需要中文字形，可以改用体积更小的 `NF` 版本：

```bash
brew install --cask font-maple-mono-nf
```

同时把 `ghostty/config` 中的字体族名改为 `Maple Mono NF`：

```ini
font-family = "Maple Mono NF"
```

也可以手动安装：从 [Maple Mono 官网](https://font.subf.dev/en/download/) 或 [GitHub Releases](https://github.com/subframe7536/maple-font/releases) 下载 `MapleMono-NF-CN-*.ttf`（或 `MapleMono-NF-*.ttf`），双击安装，或复制到 `~/Library/Fonts/`。

验证字体是否安装成功：

```bash
ls ~/Library/Fonts | grep -i 'MapleMono'
```

在 macOS 上，一键安装脚本会使用 Python 3 调用 CoreText，将 `~/Library/Fonts/` 中的 `MapleMono-NF-*.ttf` 和 `MapleMono-NF-CN-*.ttf` 注册到当前用户字体库，兼容不带中文字形的 NF 版本；两个版本同时存在时都会注册，已注册的字体会自动跳过。脚本不会下载字体；缺少字体、Python 3 或注册失败时会给出提示，并继续安装工具配置。卸载配置时保留字体注册。

安装或更换字体后，重启终端应用；VS Code 可以执行 `Developer: Reload Window`。如果复制字体后仍显示图标方框，可用 macOS「字体簿」安装字体，或单独执行注册，不必卸载现有配置：

```bash
./install.sh register-fonts
```

也可以通过 curl 单独注册字体，无需下载仓库，也不会修改工具配置：

```bash
curl -fsSL https://raw.githubusercontent.com/sky-stroller/terminal-config/main/install.sh | bash -s -- register-fonts
```

### 其他终端

其他终端不会自动继承 Ghostty 的字体设置，需要手动选择 `Maple Mono NF CN`：

| 终端 | 设置方式 |
|------|----------|
| iTerm2 | `Settings → Profiles → Text → Font`，建议 Non-ASCII Font 也选同一字体 |
| Terminal.app | `Settings → Profiles → Text → Font → Change` |
| VS Code | `settings.json` 中设置 `editor.fontFamily` 和 `terminal.integrated.fontFamily` |
| Alacritty | `[font.normal] family = "Maple Mono NF CN"` |
| Kitty | `font_family Maple Mono NF CN` |
| WezTerm | `wezterm.font("Maple Mono NF CN")` |
| Warp | `Settings → Appearance → Font` |

VS Code 示例：

```json
{
  "editor.fontFamily": "Maple Mono NF CN",
  "terminal.integrated.fontFamily": "Maple Mono NF CN",
  "terminal.integrated.fontLigatures": true
}
```

Alacritty 示例：

```toml
[font]
size = 13

[font.normal]
family = "Maple Mono NF CN"
style = "Regular"
```

Kitty 示例：

```conf
font_family Maple Mono NF CN
font_size 13
```

WezTerm 示例：

```lua
config.font = wezterm.font("Maple Mono NF CN")
config.font_size = 13
```

注意要选择带 **NF** 的版本；`Maple Mono CN` 不含 Nerd Font 图标。通过 SSH 连接远程时，字体由本地终端渲染，远程机器不需要安装字体；tmux 也不会改变字体。

## Starship 安装

macOS 推荐用 Homebrew：

```bash
brew install starship
```

没有 Homebrew 时可以使用官方安装脚本：

```bash
curl -sS https://starship.rs/install.sh | sh
```

`install.sh` 会在检测到 zsh 时自动把下面这行写入 `~/.zshrc`：

```bash
# ~/.zshrc
eval "$(starship init zsh)"
```

如果 `~/.zshrc` 已包含 `starship init zsh`，脚本会跳过自动写入，避免重复。手动安装时需要自行添加这一行。

重新加载 shell：

```bash
exec zsh
```

验证：

```bash
starship --version
```

`install.sh` 会自动检测 Starship，缺失时优先通过 Homebrew 安装；没有 Homebrew 时回退到官方安装脚本。

## 安装

### curl 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/sky-stroller/terminal-config/main/install.sh | bash
```

脚本会自动下载仓库配置到临时目录，安装完成后清理。

卸载：

```bash
curl -fsSL https://raw.githubusercontent.com/sky-stroller/terminal-config/main/install.sh | bash -s -- --uninstall
```

### 本地安装

```bash
chmod +x install.sh
./install.sh
```

卸载：

```bash
./install.sh --uninstall
```

脚本会：

- 检查 Ghostty、Vim 和 macOS 上的 VS Code，只安装检测到的工具配置
- 检测到 macOS VS Code 时，设置用户配置中的 `editor.fontFamily` 和 `terminal.integrated.fontFamily`：优先使用已安装的 `Maple Mono NF CN`，只有 NF 时使用 `Maple Mono NF`，未检测到字体文件时沿用默认的 NF CN
- VS Code 配置写入 `~/Library/Application Support/Code/User/settings.json`，需要 Python 3；保留 JSONC 注释、格式和其他设置，配置无效时提示并跳过
- Starship 缺失时优先通过 Homebrew 自动安装，没有 Homebrew 时使用官方安装脚本
- 检测到 zsh 时，把 Starship 初始化写入 `~/.zshrc`（带标记块，卸载时移除）
- 安装前把已有配置备份到 `~/.config/terminal-config/backup-<时间戳>/`
- 把安装记录写入 `~/.config/terminal-config/state`
- Ghostty/Starship 使用复制方式，Vim 使用标记块追加到 `~/.vimrc`

> 首次从手动安装迁移时，如果 `~/.vimrc` 已包含 `t_SI` / `t_EI` / `t_SR` 但没有 `terminal-config` 标记，脚本会跳过 Vim 配置以避免重复；请先手动移除旧配置。

卸载时会恢复安装前的 Ghostty/Starship 配置及 VS Code 用户配置文件（整个文件恢复为备份；若原文件不存在则删除脚本创建的文件），并从 `~/.vimrc` 和 `~/.zshrc` 移除脚本添加的标记块。

也可以手动安装：

```bash
# Ghostty
mkdir -p ~/.config/ghostty
cp ghostty/config ~/.config/ghostty/config

# Starship
cp starship/starship.toml ~/.config/starship.toml

# Vim：追加到现有 vimrc，不要覆盖
cat vim/cursor.vim >> ~/.vimrc
```

如果 `~/.vimrc` 已有内容，建议先备份。重复执行追加命令会产生重复配置，可以用下面的幂等写法：

```bash
grep -q 'let &t_SR' ~/.vimrc || cat vim/cursor.vim >> ~/.vimrc
```

## Ghostty

当前配置的要点：

- 字体：`Maple Mono NF CN` 13pt，加粗渲染，行高 `+10%`
- 主题：`Catppuccin Mocha`
- 窗口：12/8 内边距、0.92 半透明、20 级毛玻璃模糊、标签栏融入标题栏
- 光标：细竖线、闪烁
- 交互：选中即复制、打字隐藏鼠标、关闭不确认、启用 zsh shell 集成
- 图标：`macos-icon = xray`，修改后需要重启 Ghostty

修改配置后按 `Cmd+Shift+,` 重载，或重启 Ghostty。

### 光标行为说明

Ghostty 的 `cursor-style` 只是**默认光标样式**，应用可以通过 `CSI q` 覆盖。默认的 shell 集成包含 `cursor` 特性，会在提示符处强制把光标设为竖线，因此：

- 提示符处始终是竖线，改 `cursor-style` 不会生效
- 想让 `cursor-style` 在提示符处生效，需要关闭该特性：

```ini
shell-integration-features = no-cursor,no-sudo,title,no-ssh-env,no-ssh-terminfo,path
```

## Starship

`starship/starship.toml` 基于官方 `catppuccin-powerline` 预设改造：

- 彩虹条占一行，输入符号 `❯` 另起一行
- 三段配色：red → peach → lavender
- 目录最多显示 6 层，常用目录替换为图标
- 显示 Git 分支/状态、Node、Bun、Rust、Go、Python、Conda、Docker 等模块
- 命令耗时显示到毫秒，超过 45 秒发送系统通知

切换调色板只需修改：

```toml
palette = 'catppuccin_mocha'
```

可选值：`catppuccin_mocha`、`catppuccin_frappe`、`catppuccin_latte`、`catppuccin_macchiato`。

## Vim

`vim/cursor.vim` 显式设置终端光标形状：

```vim
" 插入模式：闪烁竖线
let &t_SI = "\e[5 q"
" 普通模式：闪烁方块
let &t_EI = "\e[1 q"
" 替换模式：闪烁下划线
let &t_SR = "\e[3 q"
```

| 变量 | 作用 |
|------|------|
| `t_SI` | 进入插入模式时发送 |
| `t_EI` | 退出插入/替换模式时发送 |
| `t_SR` | 进入替换模式时发送 |
| `t_RS` | 查询终端光标样式，**不是**设置替换模式 |

当前环境的 terminfo 缺少 `Ss`/`Se`，Vim 的 `guicursor` 不会自动下发光标序列，因此需要手动设置 `t_SI` / `t_EI` / `t_SR`。

替换模式用 `R` 进入，`Esc` 退出。修改后执行 `:source ~/.vimrc` 或重新打开 Vim。

## 验证

在仓库根目录执行：

```bash
# Ghostty 配置语法
ghostty +validate-config --config-file=ghostty/config

# Starship 配置解析
STARSHIP_CONFIG=$PWD/starship/starship.toml starship print-config >/dev/null && echo "starship OK"

# Vim 光标选项（三项都非空则通过）
vim -Nu ~/.vimrc -es \
  -c 'if &t_SI == "" || &t_EI == "" || &t_SR == "" | cquit | endif' \
  -c 'q!' && echo "vim OK"
```

如果 `ghostty` 不在 `PATH` 中，可以使用完整路径：

```bash
/Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config --config-file=ghostty/config
```

## 同步方式

仓库是配置源，`~/.config` 下是实际生效的副本。修改仓库后需要重新复制：

```bash
cp ghostty/config ~/.config/ghostty/config
cp starship/starship.toml ~/.config/starship.toml
```

也可以改用符号链接：

```bash
ln -sf "$PWD/ghostty/config" ~/.config/ghostty/config
ln -sf "$PWD/starship/starship.toml" ~/.config/starship.toml
```

Vim 配置不建议直接链接整个 `~/.vimrc`，可以在 vimrc 中使用：

```vim
source /path/to/terminal-config/vim/cursor.vim
```
