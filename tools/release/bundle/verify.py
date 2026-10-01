"""Verify a signed bundle without loading images or mutating the installation."""
import argparse
import json
from pathlib import Path
from scripts.qa11_release.verify_oci import verify as verify_oci
from .files import check_files
from .manifest import require, validate
from .signature import verify as verify_signature


def verify_bundle(root: Path, public_key: Path, revision: str):
    document = root / "manifest.json"
    verify_signature(document, public_key)
    manifest = json.loads(document.read_text(encoding="utf-8"))
    validate(manifest)
    require(manifest["source_revision"] == revision, "Transport and manifest source SHA differ")
    check_files(root, manifest)
    for component in manifest["components"].values():
        receipt = verify_oci(root / component["archive"], revision, manifest["source_archive_sha256"], component["index_digest"])
        for key in ("index_digest", "manifest_digest", "attestation_predicates"):
            require(receipt[key] == component[key], "Manifest and OCI attestation differ")
    return manifest


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    parser.add_argument("revision")
    parser.add_argument("--public-key", type=Path, default=Path("/etc/voice-platform/release-signing.pub.pem"))
    args = parser.parse_args()
    verify_bundle(args.directory.resolve(), args.public_key, args.revision)
    print("Signed release bundle verified")


if __name__ == "__main__":
    main()
