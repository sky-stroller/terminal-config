"""验证工具安装、Zsh 初始化顺序和卸载时的用户配置保留。"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

INSTALLER = Path(__file__).resolve().parents[1] / 'install.sh'
FUNCTIONS = INSTALLER.read_text().split('case "${1:-install}" in', 1)[0]


class ShellToolsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.environment = {
            **os.environ, 'HOME': str(self.home), 'SHELL': '/bin/zsh',
            'ZDOTDIR': str(self.home / 'zsh config'),
            'XDG_CONFIG_HOME': str(self.home / '.config'), 'LC_ALL': 'en_US.UTF-8',
        }
        self.target = self.home / 'zsh config/.zshrc'
        self.target.parent.mkdir()

    def run_installer(self, commands):
        result = subprocess.run(
            ['bash', '-c', FUNCTIONS + '\n' + commands],
            env=self.environment, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def install(self):
        self.run_installer('''
brew() { printf '%s\n' "$HOME/brew prefix"; }
mkdir -p "$STATE_DIR"
: > "$STATE_FILE"
install_zshrc
''')

    @unittest.skipUnless(shutil.which('zsh'), '需要 Zsh 验证配置加载')
    def test_paths_precede_user_compinit_and_existing_integrations_are_preserved(self):
        original = '''# 用户配置
[[ $fpath[1] == "$HOME/brew prefix/share/zsh-completions" ]] || return 10
compdef() { :; }
fzf-history-widget() { :; }
__zoxide_z() { :; }
_zsh_autosuggest_start() { :; }
_zsh_highlight() { :; }
# starship init zsh 已由用户管理
'''
        self.target.write_text(original)
        # 如果重复加载任何已有集成，测试就会失败。
        binary_dir = self.home / 'bin'
        binary_dir.mkdir()
        for name in ('fzf', 'zoxide', 'starship'):
            binary = binary_dir / name
            binary.write_text('#!/bin/sh\necho unexpected-initialization >&2\nexit 99\n')
            binary.chmod(0o755)
        self.environment['PATH'] = str(binary_dir) + ':' + os.environ['PATH']
        self.install()
        result = subprocess.run(
            ['zsh', '-fc', 'source "$ZDOTDIR/.zshrc"'],
            env=self.environment, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        self.run_installer('do_uninstall')
        self.assertEqual(self.target.read_text().strip(), original.strip())

    def test_new_config_is_valid_and_removed_on_uninstall(self):
        self.install()
        if shutil.which('zsh'):
            subprocess.run(['zsh', '-n', str(self.target)], check=True)
        self.run_installer('do_uninstall')
        self.assertFalse(self.target.exists())

    def test_brew_receives_all_seven_packages_and_failure_is_nonfatal(self):
        result = self.run_installer('''
brew() { printf '%s\n' "$*"; return 1; }
install_shell_tools
''')
        self.assertIn(
            'install zsh-autosuggestions zsh-syntax-highlighting zsh-completions zoxide eza bat fzf',
            result.stdout,
        )
        self.assertIn('部分工具安装失败', result.stdout)


if __name__ == '__main__':
    unittest.main()
