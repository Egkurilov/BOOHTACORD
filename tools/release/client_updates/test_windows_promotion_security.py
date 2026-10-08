import hashlib
import json
import zipfile

import pytest

from tools.release.client_updates.promote_windows_release import promote


def fixture(tmp_path, member):
    data = b"payload"
    manifest = {"schema_version": 1, "version": "1.0.39+72",
        "release_id": "windows-direct-stable-r53", "release_order": 53,
        "platform": "windows", "architectures": ["x64"],
        "files": {member: {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}}}
    raw = (json.dumps(manifest, sort_keys=True) + "\n").encode()
    archive = tmp_path / "BOOHTACORD-windows-v1.0.39-x64.zip"
    with zipfile.ZipFile(archive, "w") as bundle:
        bundle.writestr(member, data)
        bundle.writestr("artifact-manifest.json", raw)
    manifest_path = tmp_path / "artifact-manifest.json"
    manifest_path.write_bytes(raw)
    sums = tmp_path / "SHA256SUMS"
    sums.write_text(f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n"
                    f"{hashlib.sha256(raw).hexdigest()}  {manifest_path.name}\n", encoding="utf-8")
    catalog = tmp_path / "catalog.json"
    catalog.write_text(json.dumps({"schema_version": 1, "catalog_revision": 9,
        "application_family": "boohtacord", "entries": [{"platform": "windows",
        "distribution": "direct", "channel": "stable", "arch": "x64",
        "state": "unconfigured", "target": None}]}), encoding="utf-8")
    release = {"tag_name": "windows-v1.0.39", "draft": False, "prerelease": False,
               "published_at": "2026-10-08T10:00:00Z"}
    return catalog, release, archive, manifest_path, sums


def test_duplicate_checksum_names_fail_before_catalog_write(tmp_path):
    catalog, release, archive, manifest, sums = fixture(tmp_path, "app.exe")
    original = catalog.read_bytes()
    line = sums.read_text(encoding="utf-8").splitlines()[0]
    sums.write_text(line + "\n" + line + "\n", encoding="utf-8")

    with pytest.raises(ValueError, match="duplicate checksum"):
        promote(catalog, 9, release, archive, manifest, sums, "Egkurilov/BOOHTACORD")
    assert catalog.read_bytes() == original


def test_malicious_checksum_path_fails_before_catalog_write(tmp_path):
    catalog, release, archive, manifest, sums = fixture(tmp_path, "app.exe")
    original = catalog.read_bytes()
    raw = sums.read_text(encoding="utf-8").splitlines()
    sums.write_text(raw[0].replace(archive.name, "../" + archive.name) + "\n" + raw[1] + "\n",
                    encoding="utf-8")

    with pytest.raises(ValueError, match="unexpected assets"):
        promote(catalog, 9, release, archive, manifest, sums, "Egkurilov/BOOHTACORD")
    assert catalog.read_bytes() == original


def test_zip_path_traversal_fails_before_catalog_write(tmp_path):
    catalog, release, archive, manifest, sums = fixture(tmp_path, "../outside.exe")
    original = catalog.read_bytes()

    with pytest.raises(ValueError, match="unsafe path"):
        promote(catalog, 9, release, archive, manifest, sums, "Egkurilov/BOOHTACORD")
    assert catalog.read_bytes() == original
