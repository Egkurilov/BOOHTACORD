"""Verify every payload and bind successful gate receipts to the release SHA."""
import hashlib
import json
from pathlib import Path
from .manifest import require

GATES = {"backend", "web", "contracts", "artifact_smoke"}


def sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def check_receipt(receipt, revision):
    require(receipt.get("source_revision") == revision, "Checks belong to another source revision")
    checks = receipt.get("checks", {})
    require(set(checks) == GATES, "Required release checks are missing or unknown")
    require(all(value == "PASS" for value in checks.values()), "Release checks did not all pass")


def check_files(root: Path, manifest):
    for name, expected in manifest["files"].items():
        path = root / name
        require(path.is_file() and not path.is_symlink() and path.parent == root, "Missing/unsafe payload")
        require(path.stat().st_size == expected["bytes"], "Payload size differs: " + name)
        require(sha256(path) == expected["sha256"], "Payload checksum differs: " + name)
    check_receipt(json.loads((root / "checks.json").read_text(encoding="utf-8")), manifest["source_revision"])
