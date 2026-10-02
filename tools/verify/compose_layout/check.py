"""Verify canonical production/dev entrypoints without contacting a Docker daemon."""
import json
import os
import subprocess
from pathlib import Path
from .model import compare


def resolve(root, *files):
    cli = [os.environ['VOICE_PLATFORM_COMPOSE_CLI']] if os.environ.get('VOICE_PLATFORM_COMPOSE_CLI') else ['docker', 'compose']
    arguments = [*cli, '--env-file', str(root / '.env.example'), '--profile', 'operator']
    for path in files: arguments += ['-f', str(root / path)]
    return json.loads(subprocess.check_output([*arguments, 'config', '--format', 'json'], cwd=root, text=True))


def main():
    root = Path(__file__).resolve().parents[3]
    production = resolve(root, 'deploy/compose.yaml')
    if production['name'] != 'voice-platform': raise ValueError('Deployment identity changed')
    compare(production, production)
    dev = resolve(root, 'deploy/compose.yaml', 'deploy/compose.dev.yaml')
    compare(dev, production)
    expected = {'api': root / 'backend', 'web': root / 'clients/web'}
    for name, context in expected.items():
        if Path(dev['services'][name]['build']['context']).resolve() != context:
            raise ValueError('Development build context differs: ' + name)
    print('Compose production/dev topology agrees; production contains no build')


if __name__ == '__main__':
    main()
