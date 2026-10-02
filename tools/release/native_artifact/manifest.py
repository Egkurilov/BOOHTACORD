"""Retained native artifact metadata contains measured files and explicit signing state."""
import hashlib
import json
import re
import subprocess
from pathlib import Path
from .audio_component import write_audio_component

ROOT = Path(__file__).resolve().parents[3]


def digest(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()


def version(root=ROOT):
    content = (root / 'clients/flutter/pubspec.yaml').read_text(encoding='utf-8')
    match = re.search(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)\s*$', content, re.M)
    if not match: raise ValueError('Native version/build number is unavailable')
    return match[1]


def write(directory, platform, architectures, application_id, signing, *, root=ROOT):
    directory = directory.resolve()
    if signing.get('status') not in ('signed', 'debug', 'unsigned', 'adhoc'):
        raise ValueError('Signing status must be measured and explicit')
    if signing['status'] in ('signed', 'debug') and not re.fullmatch(r'[0-9a-f]{64}', signing.get('certificate_sha256', '')):
        raise ValueError('Signed artifacts require a measured certificate fingerprint')
    audio_component = write_audio_component(directory, root=root, platform=platform)
    files = {}
    for path in sorted(directory.rglob('*')):
        if path.name in ('artifact-manifest.json', 'SHA256SUMS'): continue
        if path.is_symlink(): raise ValueError('Artifact cannot contain symlinks')
        if path.is_file(): files[path.relative_to(directory).as_posix()] = {'bytes': path.stat().st_size, 'sha256': digest(path)}
    if not files: raise ValueError('No native build artifact was produced')
    revision = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
    dirty = subprocess.run(['git', '-C', str(root), 'diff', '--quiet', 'HEAD', '--'], stderr=subprocess.DEVNULL).returncode != 0
    contracts = {path.name: digest(path) for path in sorted((root / 'contracts').glob('*')) if path.is_file()}
    if not {'openapi.yaml', 'realtime.schema.json', 'mobile-client-contract.md'} <= contracts.keys():
        raise ValueError('Native artifact contract inputs are missing from checkout')
    client_build = json.loads((root / 'contracts/client-build.json').read_text(encoding='utf-8'))
    if version(root) != f"{client_build['version']}+{client_build['native_build']}":
        raise ValueError('Native version differs from client build identity')
    result = {'schema_version': 1, 'source_revision': revision, 'source_dirty': dirty, 'version': version(root),
              'release_id': client_build['release_id'], 'release_order': client_build['release_order'],
              'platform': platform, 'architectures': architectures, 'application_id': application_id,
              'signing': signing, 'toolchains': json.loads((root / 'tools/toolchains.json').read_text()),
              'contracts': contracts, 'files': files, 'audio_component': audio_component}
    document = directory / 'artifact-manifest.json'
    document.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    checksums = [f"{value['sha256']}  {name}\n" for name, value in files.items()]
    checksums.append(f'{digest(document)}  {document.name}\n')
    (directory / 'SHA256SUMS').write_text(''.join(checksums), encoding='utf-8')
    return result
