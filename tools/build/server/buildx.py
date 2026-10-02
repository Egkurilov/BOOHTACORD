"""Obtain the checksum-pinned builder plugin only on trusted build machines."""
import json
import os
from pathlib import Path
from urllib.request import urlopen
from tools.release.bundle.files import sha256


def configure(root: Path, directory: Path):
    policy = json.loads((root / "tools/toolchains.json").read_text())
    plugin = directory / "cli-plugins/docker-buildx"
    plugin.parent.mkdir(parents=True)
    url = f"https://github.com/docker/buildx/releases/download/v{policy['buildx']}/buildx-v{policy['buildx']}.linux-amd64"
    with urlopen(url, timeout=90) as source, plugin.open("wb") as target:
        while chunk := source.read(1024 * 1024):
            target.write(chunk)
    if sha256(plugin) != policy["buildx_linux_amd64_sha256"]:
        raise ValueError("Builder plugin checksum differs")
    plugin.chmod(0o755)
    return {**os.environ, "DOCKER_CONFIG": str(directory)}
