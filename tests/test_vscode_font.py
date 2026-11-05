"""验证 VS Code 用户字体配置的合并和失败保护。"""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/configure-vscode-font.py'
spec = importlib.util.spec_from_file_location('vscode_font', SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class FontSettingsTests(unittest.TestCase):
    def test_preserves_comments_nested_settings_and_other_values(self):
        original = '''{
    // 保留说明及网址
    "url": "https://example.com/a//b",
    "[python]": {"editor.fontFamily": "Nested",},
    "editor.fontFamily": "Menlo", // 字体说明
    "terminal.integrated.fontFamily": "Old",
}'''
        result = module.configure(original, 'Maple Mono NF')
        self.assertIn('// 保留说明及网址', result)
        self.assertIn('// 字体说明', result)
        self.assertIn('"url": "https://example.com/a//b"', result)
        self.assertIn('"[python]": {"editor.fontFamily": "Nested",}', result)
        self.assertEqual(result.count(': "Maple Mono NF"'), 2)
        self.assertEqual(module.configure(result, 'Maple Mono NF'), result)

    def test_adds_missing_keys(self):
        for original in ('', '{}', '{"other": 1}', '{"other": [1, 2]}'):
            result = json.loads(module.configure(original, 'Maple Mono NF CN'))
            self.assertEqual(result['editor.fontFamily'], 'Maple Mono NF CN')
            self.assertEqual(result['terminal.integrated.fontFamily'], 'Maple Mono NF CN')

    def test_handles_comments_trailing_comma_and_duplicate_keys(self):
        for original in ('{/* 注释 */}', '{"other": true, // 保留\n}',
                         '{"editor.fontFamily": "A", "editor.fontFamily": "B"}'):
            result = module.configure(original, 'Maple Mono NF')
            self.assertNotIn('"A"', result)
            self.assertNotIn('"B"', result)
            self.assertEqual(module.configure(result, 'Maple Mono NF'), result)

    def test_invalid_settings_are_not_modified(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'settings.json'
            for original in ('{"broken":', '[]', '{"a": 1,,}'):
                path.write_text(original)
                result = subprocess.run([sys.executable, str(SCRIPT), str(path), 'Maple Mono NF'], capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(path.read_text(), original)

    def test_cli_creates_user_settings_in_path_with_spaces(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'Application Support/Code/User/settings.json'
            subprocess.run([sys.executable, str(SCRIPT), str(path), 'Maple Mono NF'], check=True)
            self.assertEqual(json.loads(path.read_text())['editor.fontFamily'], 'Maple Mono NF')

    def test_install_selects_font_and_uninstall_restores_settings(self):
        installer = SCRIPT.parents[1] / 'install.sh'
        functions = installer.read_text().split('case "${1:-install}" in', 1)[0]
        for family, filename in [('Maple Mono NF', 'MapleMono-NF-Regular.ttf'),
                                 ('Maple Mono NF CN', 'MapleMono-NF-CN-Regular.ttf')]:
            for existing in (False, True):
                with tempfile.TemporaryDirectory() as directory:
                    home = Path(directory)
                    fonts = home / 'Library/Fonts'
                    fonts.mkdir(parents=True)
                    (fonts / filename).touch()
                    target = home / 'Library/Application Support/Code/User/settings.json'
                    original = '{\n // 用户说明\n "editor.fontFamily": "Old",\n "other": true,\n}\n'
                    if existing:
                        target.parent.mkdir(parents=True)
                        target.write_text(original)
                    environment = {**os.environ, 'HOME': str(home), 'LC_ALL': 'en_US.UTF-8',
                                   'XDG_CONFIG_HOME': str(home / '.config')}
                    setup = functions + '''
ROOT_DIR="$1"
uname() { echo Darwin; }
code() { :; }
mkdir -p "$STATE_DIR"
: > "$STATE_FILE"
install_vscode
'''
                    subprocess.run(['bash', '-c', setup, '测试安装', str(SCRIPT.parents[1])],
                                   env=environment, capture_output=True, check=True)
                    self.assertIn('"terminal.integrated.fontFamily": "' + family + '"', target.read_text())
                    subprocess.run(['bash', '-c', functions + '\ndo_uninstall\n'],
                                   env=environment, capture_output=True, check=True)
                    if existing:
                        self.assertEqual(target.read_text(), original)
                    else:
                        self.assertFalse(target.exists())


if __name__ == '__main__':
    unittest.main()
