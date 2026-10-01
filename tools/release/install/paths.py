"""Resolve canonical runtime paths while supporting already retained signed releases."""
from pathlib import Path


def retained_path(directory, canonical, legacy):
    path = Path(directory) / canonical
    return path if path.is_file() else Path(directory) / legacy


def compose_arguments(directory):
    path = retained_path(directory, 'deploy/compose.yaml', 'compose.yaml')
    return ['--project-directory', str(path.parent), '--env-file', str(directory / '.env'), '-f', str(path)]


def rollout_script(directory):
    return retained_path(directory, 'tools/release/rollout/deploy-images.sh', 'scripts/deploy-images.sh')
