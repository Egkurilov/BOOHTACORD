"""Prove retained releases, current state and conservative schema compatibility."""
import re
import shutil
from pathlib import Path
from tools.release.bundle.compatibility import compatible_rollback
from tools.release.bundle.manifest import require
from tools.release.bundle.verify import verify_bundle
from tools.release.install.docker import docker, verify_running
from tools.release.install.guards import disk_budget
from tools.release.install.runtime import verify_runtime
from tools.release.install.state import current_manifest


def preflight(root, current_revision, previous_revision, public_key):
    require(all(re.fullmatch('[0-9a-f]{40}', revision) for revision in (current_revision, previous_revision))
            and current_revision != previous_revision, 'Distinct full revisions are required')
    observed = current_manifest(root, public_key)
    require(observed['source_revision'] == current_revision, 'Current deployment changed before rollback')
    manifests = []
    for revision in (current_revision, previous_revision):
        directory = root / revision
        require(directory.resolve() == directory and directory.is_dir(), 'Exact retained release directory is unavailable')
        manifest = verify_bundle(directory, public_key, revision)
        verify_runtime(directory)
        manifests.append(manifest)
    current, previous = manifests
    compatible_rollback(current, previous)
    verify_running(root / current_revision, current)
    payload_size = sum(item['bytes'] for item in previous['files'].values())
    disk_budget(shutil.disk_usage(root).free, payload_size)
    docker_root = Path(docker('info', '--format', '{{.DockerRootDir}}'))
    disk_budget(shutil.disk_usage(docker_root).free, payload_size)
    return current, previous
