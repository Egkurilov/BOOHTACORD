"""Install already-built, signed artifacts. Requires provisioned host trust and runtime."""
import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from tools.release.archive.extract import extract
from tools.release.bundle.compatibility import compatible_upgrade
from tools.release.bundle.files import sha256
from tools.release.bundle.manifest import require
from tools.release.bundle.verify import verify_bundle
from .docker import deploy, docker, load_images, verify_running
from .guards import disk_budget
from .state import current_manifest, write_receipt


def install(args):
    import fcntl
    require(re.fullmatch(r"[0-9a-f]{40}", args.revision), "Full revision is required")
    require(re.fullmatch(r"[0-9a-f]{64}", args.sha256), "Bundle checksum is required")
    require(args.bundle.is_file() and sha256(args.bundle) == args.sha256, "Transferred bundle checksum differs")
    root = args.release_root.resolve()
    root.mkdir(mode=0o750, parents=True, exist_ok=True)
    with (root / ".install.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        disk_budget(shutil.disk_usage(root).free, args.bundle.stat().st_size)
        docker_root = Path(docker("info", "--format", "{{.DockerRootDir}}"))
        disk_budget(shutil.disk_usage(docker_root).free, args.bundle.stat().st_size)
        with tempfile.TemporaryDirectory(prefix=".incoming.", dir=root) as staging:
            incoming = Path(staging) / "bundle"
            extract(args.bundle, incoming, max_bytes=min(8_000_000_000, shutil.disk_usage(root).free - 2_147_483_648))
            manifest = verify_bundle(incoming, args.public_key, args.revision)
            current = current_manifest(root, args.public_key)
            compatible_upgrade(current, manifest)
            runtime = Path(staging) / "runtime"
            extract(incoming / "runtime.tar.gz", runtime, max_bytes=100_000_000)
            subprocess.run(["bash", str(runtime / "scripts/check-attachment-volume-headroom.sh")], check=True)
            destination = root / args.revision
            if destination.exists():
                existing = verify_bundle(destination, args.public_key, args.revision)
                require(existing == manifest, "Immutable release directory contains another artifact")
                for source in runtime.rglob("*"):
                    if source.is_file():
                        target = destination / source.relative_to(runtime)
                        require(target.is_file() and not target.is_symlink() and sha256(target) == sha256(source),
                                "Retained runtime differs from the signed artifact")
            else:
                for path in runtime.iterdir():
                    require(not (incoming / path.name).exists(), "Runtime payload conflicts with release artifacts")
                    path.rename(incoming / path.name)
                incoming.rename(destination)
            require(args.environment.is_file(), "Production environment is unavailable")
            # The secure environment remains host-only and never enters an artifact.
            env_path = destination / ".env"
            descriptor = os.open(env_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(descriptor, "wb") as target, args.environment.open("rb") as source:
                shutil.copyfileobj(source, target)
            env_path.chmod(0o600)
            load_images(destination, manifest)
            deploy(destination, manifest)
            verify_running(destination, manifest)
            write_receipt(destination, manifest)
            print("Installed verified source revision " + args.revision)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle", type=Path)
    parser.add_argument("revision")
    parser.add_argument("sha256")
    parser.add_argument("--release-root", type=Path, default=Path("/opt/voice-platform-releases"))
    parser.add_argument("--environment", type=Path, default=Path("/opt/voice-platform/.env"))
    parser.add_argument("--public-key", type=Path, default=Path("/etc/voice-platform/release-signing.pub.pem"))
    install(parser.parse_args())


if __name__ == "__main__":
    main()
