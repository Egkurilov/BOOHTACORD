"""Read GitHub's base revision without shell-interpolating event fields."""
import json
import os
import re
import subprocess
from pathlib import Path
from .selection import ALL, select


def changed_paths(event, event_name):
    if event_name == 'pull_request':
        base = event.get('pull_request', {}).get('base', {}).get('sha')
    elif event_name == 'push':
        base = event.get('before')
    else:
        return None
    if not isinstance(base, str) or not re.fullmatch(r'[0-9a-f]{40}', base) or base == '0' * 40:
        return None
    result = subprocess.run(['git', 'diff', '--name-only', '--no-renames', '-z', base, 'HEAD', '--'], capture_output=True)
    if result.returncode:
        return None
    return list(filter(None, result.stdout.decode('utf-8', errors='strict').split('\0')))


def main():
    event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text(encoding='utf-8'))
    chosen = select(changed_paths(event, os.environ.get('GITHUB_EVENT_NAME')))
    result = '\n'.join(f'{name}={str(name in chosen).lower()}' for name in sorted(ALL)) + '\n'
    with Path(os.environ['GITHUB_OUTPUT']).open('a', encoding='utf-8') as output:
        output.write(result)
    print(result, end='')


if __name__ == '__main__':
    main()
