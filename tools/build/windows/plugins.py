"""Use exact Windows plugin source paths where CMake cannot traverse Flutter links."""
import json
import re
from pathlib import Path


def configure(client):
    metadata = json.loads((client / '.flutter-plugins-dependencies').read_text(encoding='utf-8'))
    cmake = client / 'windows/flutter/generated_plugins.cmake'
    content = cmake.read_text(encoding='utf-8')
    lines = []
    for plugin in metadata['plugins']['windows']:
        root = Path(plugin['path']).resolve()
        if not (root / 'windows/CMakeLists.txt').is_file(): continue
        if not re.fullmatch('[a-z0-9_]+', plugin['name']) or re.search('[";]', str(root)):
            raise ValueError('Unsupported plugin name or path')
        lines.append(f'set(BOOHTACORD_PLUGIN_SOURCE_{plugin["name"]} "{root.as_posix()}")')
    for variable in ('plugin', 'ffi_plugin'):
        original = 'flutter/ephemeral/.plugin_symlinks/${' + variable + '}/windows'
        if original not in content: raise ValueError('Unexpected generated CMake file')
        content = content.replace(original, '"${BOOHTACORD_PLUGIN_SOURCE_${' + variable + '}}/windows"')
    cmake.write_text('\n'.join(lines) + '\n' + content, encoding='utf-8')
