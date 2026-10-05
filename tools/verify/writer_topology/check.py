"""Release preflight for the single attachment-writer topology."""
from pathlib import Path
import yaml


def validate(compose):
    deployment = compose['services']['api'].get('deploy', {})
    if deployment.get('replicas') != 1:
        raise ValueError('Exactly one API attachment writer is supported')
    for action in ('update_config', 'rollback_config'):
        if deployment.get(action, {}).get('order') != 'stop-first':
            raise ValueError('API rollout and rollback must stop the previous writer first')


def main():
    root = Path(__file__).resolve().parents[3]
    validate(yaml.safe_load((root/'deploy/compose.yaml').read_text()))
    print('Single attachment writer topology PASS')


if __name__ == '__main__':
    main()
