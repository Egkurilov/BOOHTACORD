"""Verify RNNoise provenance and bytes served by the exact release web image."""
import hashlib
import json
from urllib.error import HTTPError
from urllib.request import urlopen

PATH = '/audio/rnnoise/v0.1-cdf196b/'
MODEL = 'f0cdb52b30501aab489f90fedbc7a023c719d91b337db2da7f26fc3036556b95'
SOURCE = 'cdf196b1e9de2f8ff1003328ebf9a4316477429d'


def verify_wasm(content_type, data, checksum):
    if content_type.split(';')[0].strip() != 'application/wasm' or not data.startswith(b'\0asm'):
        raise ValueError('Release WASM response is invalid (possible SPA fallback)')
    if hashlib.sha256(data).hexdigest() != checksum:
        raise ValueError('Release WASM does not match the manifest')


def fetch(base, name, mime):
    with urlopen(base.rstrip('/') + PATH + name, timeout=10) as response:
        if response.status != 200 or response.headers.get_content_type() != mime:
            raise ValueError('Release audio asset MIME/status differs: ' + name)
        data = response.read(1_000_001)
        if len(data) > 1_000_000: raise ValueError('Release audio asset exceeds bounded size')
        return data


def verify_served_audio(base):
    manifest = json.loads(fetch(base, 'rnnoise-manifest.json', 'application/json'))
    if manifest['sourceCommit'] != SOURCE or manifest['modelSha256'] != MODEL:
        raise ValueError('Release audio source/model identity differs')
    verify_wasm('application/wasm', fetch(base, 'rnnoise.wasm', 'application/wasm'), manifest['wasmSha256'])
    sbom = json.loads(fetch(base, 'rnnoise-sbom.cdx.json', 'application/json'))
    if sbom.get('bomFormat') != 'CycloneDX' or not any(item.get('name') == 'rnnoise' for item in sbom.get('components', [])):
        raise ValueError('RNNoise component SBOM is missing')
    if b'Redistribution' not in fetch(base, 'RNNOISE-NOTICES.txt', 'text/plain'):
        raise ValueError('RNNoise distribution notice is missing')
    try:
        with urlopen(base.rstrip('/') + PATH + 'missing.wasm', timeout=10):
            raise ValueError('Missing audio asset was served as a SPA response')
    except HTTPError as error:
        if error.code != 404: raise
    return manifest
