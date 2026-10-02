"""Build vendored official RNNoise with the pinned Emscripten scalar toolchain."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
LOCK = json.loads((HERE / 'rnnoise_build_lock.json').read_text())
UPSTREAM = ROOT / 'clients/flutter/packages/flutter_webrtc/common/rnnoise/upstream'
SOURCES = ['denoise.c', 'kiss_fft.c', 'pitch.c', 'celt_lpc.c', 'rnn.c', 'rnn_data.c']

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    compiler = os.environ.get('EMCC') or shutil.which('emcc')
    if not compiler:
        raise SystemExit('Install official Emscripten 4.0.20 and activate its environment; emcc missing')
    version = subprocess.check_output([compiler, '--version'], text=True)
    if f'emcc (Emscripten gcc/clang-like replacement + linker emulating GNU ld) {LOCK["emscriptenVersion"]}' not in version:
        raise SystemExit('RNNoise build requires exactly Emscripten ' + LOCK['emscriptenVersion'])
    if digest(UPSTREAM / 'src/rnn_data.c') != LOCK['modelSha256']:
        raise SystemExit('Vendored stock model checksum mismatch')
    checksums = json.loads((HERE / 'rnnoise_upstream_checksums.json').read_text())
    for relative, expected in checksums.items():
        if digest(UPSTREAM / relative) != expected:
            raise SystemExit('Vendored source checksum mismatch: ' + relative)
    output = ROOT / 'clients/web/public/audio/rnnoise' / LOCK['version']
    output.mkdir(parents=True, exist_ok=True)
    command = [compiler, '-O3', '-DNDEBUG', '-DRNNOISE_BUILD', '-I' + str(UPSTREAM / 'include'),
               '-I' + str(UPSTREAM / 'src'), *[str(UPSTREAM / 'src' / name) for name in SOURCES],
               str(HERE / 'rnnoise_bridge.c'), '-lm', '--no-entry', '-sSTANDALONE_WASM=1',
               '-sALLOW_MEMORY_GROWTH=0', '-sINITIAL_MEMORY=16777216', '-sSTACK_SIZE=1048576',
               '-sFILESYSTEM=0', '-sMALLOC=emmalloc', '-sASSERTIONS=0',
               '-sEXPORTED_FUNCTIONS=["_ns_init","_ns_reset","_ns_input","_ns_output","_ns_process"]',
               '-o', str(output / 'rnnoise.wasm')]
    subprocess.run(command, check=True, env={**os.environ, 'SOURCE_DATE_EPOCH': '1514764800'})
    manifest = {**LOCK, 'wasmFile': 'rnnoise.wasm', 'wasmSha256': digest(output / 'rnnoise.wasm'),
                'sampleRate': 48000, 'frameSize': 480, 'pcmScale': 32768, 'threads': 1, 'simd': False}
    (output / 'rnnoise-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    shutil.copyfile(UPSTREAM / 'COPYING', output / 'RNNOISE-NOTICES.txt')
    (output / 'rnnoise-sbom.cdx.json').write_text(json.dumps({
        'bomFormat': 'CycloneDX', 'specVersion': '1.5', 'version': 1,
        'components': [{'type': 'library', 'name': 'rnnoise', 'version': LOCK['version'],
        'purl': 'pkg:github/xiph/rnnoise@' + LOCK['sourceCommit'],
        'licenses': [{'license': {'id': 'BSD-3-Clause'}}],
        'hashes': [{'alg': 'SHA-256', 'content': LOCK['sourceArchiveSha256']}],
        'properties': [{'name': 'rnnoise:model:sha256', 'value': LOCK['modelSha256']},
                       {'name': 'rnnoise:wasm:sha256', 'value': manifest['wasmSha256']}]}]}, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))

if __name__ == '__main__':
    main()
