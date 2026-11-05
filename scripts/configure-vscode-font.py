#!/usr/bin/env python3
"""保留 JSONC 注释和格式，仅更新 VS Code 用户终端字体设置。"""

import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile


def configure(text, family):
    if not text.strip():
        text = '{}\n'
    # 保留每个 token 的原始位置，注释只在校验时去除。
    pattern = (r'\s+|//[^\r\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"'
               r'|[{}\[\]:,]|[^\s{}\[\]:,/]+')
    tokens = []
    position = 0
    for match in re.finditer(pattern, text):
        if match.start() != position:
            raise ValueError('配置包含无法识别的内容')
        position = match.end()
        value = match.group()
        if not value.isspace() and not value.startswith(('//', '/*')):
            tokens.append((value, match.start(), match.end()))
    if position != len(text):
        raise ValueError('配置包含无法识别的内容')
    clean = [token[0] for token in tokens]
    normalized = ''.join(value for i, value in enumerate(clean)
                         if not (value == ',' and i + 1 < len(clean) and clean[i + 1] in ('}', ']')))
    if not isinstance(json.loads(normalized), dict):
        raise ValueError('用户配置必须是 JSON 对象')

    settings = {'terminal.integrated.fontFamily'}
    missing = settings.copy()
    edits = []
    depth = 0
    for i, (value, start, end) in enumerate(tokens):
        if value in ('{', '['):
            depth += 1
        elif value in ('}', ']'):
            depth -= 1
        elif depth == 1 and value.startswith('"') and tokens[i + 1][0] == ':':
            key = json.loads(value)
            if key not in settings:
                continue
            first = i + 2
            last = first
            nested = 0
            while last < len(tokens):
                item = tokens[last][0]
                if nested == 0 and item in (',', '}'):
                    break
                if item in ('{', '['):
                    nested += 1
                elif item in ('}', ']'):
                    nested -= 1
                last += 1
            edits.append((tokens[first][1], tokens[last - 1][2], json.dumps(family)))
            missing.discard(key)

    if missing:
        newline = '\r\n' if '\r\n' in text else '\n'
        indent_match = re.search(r'\n([ \t]+)"', text)
        indent = indent_match.group(1) if indent_match else '    '
        prefix = ''
        closing = tokens[-1][1]
        if len(tokens) > 2 and tokens[-2][0] != ',':
            if tokens[-2][2] == closing:
                prefix = ','
            else:
                edits.append((tokens[-2][2], tokens[-2][2], ','))
        additions = (',' + newline).join(indent + json.dumps(key) + ': ' + json.dumps(family)
                                         for key in sorted(missing))
        edits.append((closing, closing, prefix + newline + additions + newline))
    for start, end, replacement in sorted(edits, reverse=True):
        text = text[:start] + replacement + text[end:]
    return text


def main():
    path = Path(sys.argv[1])
    text = path.read_bytes().decode('utf-8-sig') if path.exists() else '{}\n'
    result = configure(text, sys.argv[2])
    path.parent.mkdir(parents=True, exist_ok=True)
    # 同目录原子替换，避免写入中断留下不完整配置。
    descriptor, temporary = tempfile.mkstemp(dir=path.parent, prefix='.settings-')
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8', newline='') as output:
            output.write(result)
        if path.exists():
            os.chmod(temporary, stat.S_IMODE(path.stat().st_mode))
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as error:
        print(f'无法更新 VS Code 字体配置：{error}', file=sys.stderr)
        sys.exit(1)
