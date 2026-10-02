import copy
import json
import tempfile
import unittest
from pathlib import Path
from tools.release.bundle.manifest import validate
from tools.release.bundle.files import check_files, sha256
from tools.release.bundle.compatibility import compatible_upgrade, compatible_rollback


def fixture():
    digest = "a" * 64
    return {
        "schema_version": 1, "release_id": "b" * 40, "source_revision": "b" * 40,
        "source_archive_sha256": digest, "platform": "linux/amd64",
        "components": {name: {"archive": name + ".oci.tar", "index_digest": "sha256:" + digest,
            "manifest_digest": "sha256:" + digest, "attestation_predicates": [
                "https://spdx.dev/Document", "https://slsa.dev/provenance/v0.2"]} for name in ("api", "web")},
        "files": {name: {"sha256": digest, "bytes": 1} for name in
                  ("api.oci.tar", "web.oci.tar", "runtime.tar.gz", "checks.json")},
        "compatibility": {"migrations": {"0001_create.sql": digest}, "backend_tree": "c" * 40,
                          "contracts_sha256": digest, "topology_sha256": digest},
    }


class ManifestTests(unittest.TestCase):
    def test_accepts_complete_immutable_manifest(self):
        validate(fixture())

    def test_rejects_mutable_references_and_incomplete_attestation(self):
        for field, value in (("release_id", "latest"), ("source_revision", "b" * 7), ("schema_version", 2)):
            manifest = fixture()
            manifest[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError): validate(manifest)
        manifest = fixture()
        manifest["components"]["web"]["attestation_predicates"] = []
        with self.assertRaises(ValueError): validate(manifest)

    def test_rejects_missing_or_changed_files_and_receipt_from_another_commit(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = fixture()
            for name in manifest["files"]:
                (root / name).write_bytes(b"artifact")
            checks = {"source_revision": manifest["source_revision"], "checks": {
                name: "PASS" for name in ("backend", "web", "contracts", "artifact_smoke")}}
            (root / "checks.json").write_text(json.dumps(checks))
            for name in manifest["files"]:
                path = root / name
                manifest["files"][name] = {"sha256": sha256(path), "bytes": path.stat().st_size}
            check_files(root, manifest)
            (root / "api.oci.tar").write_bytes(b"tampered")
            with self.assertRaises(ValueError): check_files(root, manifest)
            (root / "api.oci.tar").write_bytes(b"artifact")
            checks["source_revision"] = "d" * 40
            (root / "checks.json").write_text(json.dumps(checks))
            manifest["files"]["checks.json"] = {"sha256": sha256(root / "checks.json"), "bytes": (root / "checks.json").stat().st_size}
            with self.assertRaises(ValueError): check_files(root, manifest)

    def test_upgrade_preserves_applied_migrations_and_rollback_requires_same_backend(self):
        current = fixture()
        newer = copy.deepcopy(current)
        newer["compatibility"]["migrations"]["0002_more.sql"] = "d" * 64
        compatible_upgrade(current, newer)
        with self.assertRaises(ValueError): compatible_upgrade(newer, current)
        with self.assertRaises(ValueError): compatible_rollback(newer, current)
        compatible_rollback(current, current)
        newer = copy.deepcopy(current)
        newer["compatibility"]["backend_tree"] = "e" * 40
        with self.assertRaises(ValueError): compatible_rollback(newer, current)


if __name__ == "__main__": unittest.main()
