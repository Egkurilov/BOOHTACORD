"""Host-owned compatibility state, including the one-time legacy source transition."""
import json
import re
from pathlib import Path
from tools.release.bundle.files import sha256
from tools.release.bundle.manifest import require, validate
from tools.release.bundle.signature import verify
from .docker import docker


def current_manifest(release_root, public_key):
    revisions = []
    for service in ("api", "web"):
        container = docker("ps", "--filter", "label=com.docker.compose.project=voice-platform",
                           "--filter", "label=com.docker.compose.service=" + service, "--format", "{{.ID}}")
        require(bool(container) and "\n" not in container, "Expected one current " + service + " container")
        revision = docker("inspect", "--format", '{{index .Config.Labels "org.opencontainers.image.revision"}}', container)
        if not re.fullmatch(r"[0-9a-f]{40}", revision):
            image = docker("inspect", "--format", "{{.Image}}", container)
            revision = docker("image", "inspect", "--format", '{{index .Config.Labels "org.opencontainers.image.revision"}}', image)
        require(re.fullmatch(r"[0-9a-f]{40}", revision), "Current source revision is unavailable")
        revisions.append(revision)
    require(revisions[0] == revisions[1], "Current API and web source revisions differ")
    current = release_root / revisions[0]
    document = current / "manifest.json"
    if document.exists():
        verify(document, public_key)
        manifest = json.loads(document.read_text())
        validate(manifest)
        require(manifest["source_revision"] == revisions[0], "Current manifest source differs")
        return manifest
    # Earlier deliveries retained their exact source. Accept only an append-only upgrade.
    migrations = current / "backend/internal/database/migrate/migrations"
    require(migrations.is_dir(), "Legacy migration inventory is missing; operator reconciliation required")
    inventory = {path.name: sha256(path) for path in migrations.glob("*.sql")}
    require(bool(inventory), "Legacy migration inventory is empty")
    return {"source_revision": revisions[0], "compatibility": {"migrations": inventory}}


def write_receipt(directory, manifest):
    receipt = {"source_revision": manifest["source_revision"], "status": "PASS",
               "running_images": {name: component["index_digest"] for name, component in manifest["components"].items()}}
    temporary = directory / "installed.json.tmp"
    temporary.write_text(json.dumps(receipt, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(directory / "installed.json")
