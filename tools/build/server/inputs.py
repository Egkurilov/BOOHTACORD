"""Release inputs are selected from Git, never from untracked build directories."""
import hashlib
import subprocess
from pathlib import Path
from tools.release.bundle.files import sha256

SOURCE_PATHS = ("backend", "clients/web", "contracts", "docker", "compose.yaml", "scripts", "tools", ".node-version", "Taskfile.yml")
RUNTIME_PATHS = ("compose.yaml", "docker/Caddyfile", "docker/livekit.yaml",
                 "tools/release/archive", "tools/release/bundle", "tools/release/install", "tools/release/rollback",
                 "tools/release/rollout/deploy-images.sh", "tools/ops/attachment_headroom/check-attachment-volume-headroom.sh",
                 "tools/ops/attachment_audit/audit-attachment-volume.sh", "tools/verify/oci/verify_oci.py",
                 "tools/verify/running_images/verify_running.sh")


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args])


def archive(root, destination, paths):
    with destination.open("wb") as stream:
        subprocess.run(["git", "-C", str(root), "archive", "--format=tar.gz", "HEAD", "--", *paths], stdout=stream, check=True)


def fingerprint(root, paths):
    names = git(root, "ls-files", "-z", "--", *paths).decode().split("\0")
    content = b"".join(name.encode() + b"\0" + git(root, "show", "HEAD:" + name) + b"\0" for name in sorted(filter(None, names)))
    return hashlib.sha256(content).hexdigest()


def compatibility(root):
    migration_root = "backend/internal/database/migrate/migrations/"
    names = git(root, "ls-files", "-z", "--", migration_root).decode().split("\0")
    return {"backend_tree": git(root, "rev-parse", "HEAD:backend").decode().strip(),
            "contracts_sha256": fingerprint(root, ("contracts",)),
            "topology_sha256": fingerprint(root, ("compose.yaml", "docker/Caddyfile", "docker/livekit.yaml")),
            "migrations": {Path(name).name: hashlib.sha256(git(root, "show", "HEAD:" + name)).hexdigest()
                           for name in names if name.endswith(".sql")}}
