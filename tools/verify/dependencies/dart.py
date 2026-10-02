"""Check repository-local Dart import edges without reading generated build trees."""
import posixpath
import re
import subprocess
from pathlib import Path

LIB = 'clients/flutter/lib/'


def violations(sources):
    errors = []
    for path, source in sources.items():
        for uri in re.findall(r"(?m)^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]", source):
            if uri.startswith('package:boohtacord_desktop/'):
                target = LIB + uri.removeprefix('package:boohtacord_desktop/')
            elif ':' in uri:
                continue
            else:
                target = posixpath.normpath(posixpath.join(posixpath.dirname(path), uri))
            if target not in sources:
                errors.append(f'{path}: local Dart dependency is absent or ignored: {target}')
            if '/lib/src/features/' in path and any(target.startswith(LIB + prefix) for prefix in
                    ('src/app_state.dart', 'src/app.dart', 'src/app/', 'src/screens/', 'src/widgets/')):
                errors.append(f'{path}: a feature owner depends on application UI: {target}')
    return errors


def main():
    root = Path(__file__).resolve().parents[3]
    names = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z', '--',
                                     'clients/flutter/lib', 'clients/flutter/test'], cwd=root).decode().split('\0')
    sources = {name: (root / name).read_text(encoding='utf-8') for name in names if name.endswith('.dart')}
    errors = violations(sources)
    if errors:
        raise RuntimeError('\n'.join(errors))
    print(f'Dart local import edges and feature/UI boundaries: OK ({len(sources)} files)')


if __name__ == '__main__':
    main()
