"""Rebuild source-bound RNNoise assets with the pinned compiler image."""
import os
import subprocess
from pathlib import Path

COMPILER_IMAGE = ('emscripten/emsdk:4.0.20@sha256:'
                  '460fff8f8ac87e11b16447fbd66538a686eafa0e4fb977aa0989ed19fe2079f7')


def compiler_command(root):
    identity = ['--user', f'{os.getuid()}:{os.getgid()}'] if os.name == 'posix' else []
    return ['docker', 'run', '--rm', *identity, '--env', 'EM_CACHE=/tmp/rnnoise-emscripten-cache',
            '-v', str(root.resolve()) + ':/src', '-w', '/src',
            COMPILER_IMAGE, 'python3', 'tools/audio/build_rnnoise.py']


def build_assets(root):
    subprocess.run(compiler_command(root), cwd=root, check=True)


if __name__ == '__main__':
    build_assets(Path(__file__).resolve().parents[2])
