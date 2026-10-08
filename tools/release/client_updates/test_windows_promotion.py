import hashlib
import json
import zipfile

import pytest

from tools.release.client_updates.promote_windows_release import promote
from tools.release.client_updates.windows_release_verification import verify_release


def make_release(tmp_path):
    payload = b"verified Windows executable"
    manifest = {
        "schema_version": 1,
        "version": "1.0.39+72",
        "release_id": "windows-direct-stable-r53",
        "release_order": 53,
        "platform": "windows",
        "architectures": ["x64"],
        "files": {"boohtacord_desktop.exe": {
            "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()
        }},
    }
    manifest_bytes = (json.dumps(manifest, sort_keys=True) + "\n").encode()
    archive = tmp_path / "BOOHTACORD-windows-v1.0.39-x64.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as package:
        package.writestr("boohtacord_desktop.exe", payload)
        package.writestr("artifact-manifest.json", manifest_bytes)
    manifest_path = tmp_path / "artifact-manifest.json"
    manifest_path.write_bytes(manifest_bytes)
    sums = tmp_path / "SHA256SUMS"
    sums.write_text(
        f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n"
        f"{hashlib.sha256(manifest_bytes).hexdigest()}  {manifest_path.name}\n",
        encoding="utf-8",
    )
    release = {
        "tag_name": "windows-v1.0.39", "draft": False, "prerelease": False,
        "published_at": "2026-10-08T10:00:00Z",
    }
    return release, archive, manifest_path, sums


def test_promote_uses_verified_windows_manifest_and_preserves_other_selectors(tmp_path):
    from tools.release.client_updates.catalog import load

    catalog = tmp_path / "catalog.json"
    catalog.write_text(json.dumps({
        "schema_version": 1, "catalog_revision": 29, "application_family": "boohtacord",
        "entries": [
            {"platform": "windows", "distribution": "direct", "channel": "stable",
             "arch": "x64", "state": "published", "target": {
                 "release_id": "windows-direct-stable-r52", "release_order": 52,
                 "version": "1.0.38", "native_build": "71", "priority": "normal",
                 "published_at": "2026-10-07T07:21:42Z", "summary": "old",
                 "release_notes_url": "https://github.com/Egkurilov/BOOHTACORD/releases/tag/windows-v1.0.38",
                 "requirements": {"supported_arches": ["x64"]},
                 "action": {"kind": "open_download_page", "url": "https://github.com/Egkurilov/BOOHTACORD/releases/tag/windows-v1.0.38"},
             }},
            {"platform": "android", "distribution": "direct", "channel": "stable",
             "arch": "arm64", "state": "unconfigured", "target": None},
        ],
    }), encoding="utf-8")
    release, archive, manifest, sums = make_release(tmp_path)

    with pytest.raises(ValueError, match="revision"):
        promote(catalog, 28, release, archive, manifest, sums, "Egkurilov/BOOHTACORD")
    assert json.loads(catalog.read_text(encoding="utf-8"))["catalog_revision"] == 29

    promote(catalog, 29, release, archive, manifest, sums, "Egkurilov/BOOHTACORD")

    document = load(catalog)
    assert document["catalog_revision"] == 30
    assert document["entries"][0]["target"] == {
        "release_id": "windows-direct-stable-r53", "release_order": 53,
        "version": "1.0.39", "native_build": "72", "priority": "normal",
        "published_at": "2026-10-08T10:00:00Z",
        "summary": "BOOHTACORD Windows 1.0.39 build 72.",
        "release_notes_url": "https://github.com/Egkurilov/BOOHTACORD/releases/tag/windows-v1.0.39",
        "requirements": {"supported_arches": ["x64"]},
        "action": {"kind": "open_download_page", "url": "https://github.com/Egkurilov/BOOHTACORD/releases/tag/windows-v1.0.39"},
    }
    assert document["entries"][1]["state"] == "unconfigured"


def test_promotion_rejects_asset_hash_mismatch_before_catalog_mutation(tmp_path):
    release, archive, manifest, sums = make_release(tmp_path)
    sums.write_text("0" * 64 + "  " + archive.name + "\n", encoding="utf-8")

    with pytest.raises(ValueError, match="checksum"):
        verify_release(release, archive, manifest, sums, "Egkurilov/BOOHTACORD")


def test_promotion_rejects_prerelease_even_with_valid_assets(tmp_path):
    release, archive, manifest, sums = make_release(tmp_path)
    release["prerelease"] = True

    with pytest.raises(ValueError, match="published stable"):
        verify_release(release, archive, manifest, sums, "Egkurilov/BOOHTACORD")


def test_repeating_promotion_for_current_release_is_a_noop(tmp_path):
    catalog = tmp_path / "catalog.json"
    catalog.write_text(json.dumps({"schema_version": 1, "catalog_revision": 29,
        "application_family": "boohtacord", "entries": [{"platform": "windows",
        "distribution": "direct", "channel": "stable", "arch": "x64",
        "state": "unconfigured", "target": None}]}), encoding="utf-8")
    release, archive, manifest, sums = make_release(tmp_path)

    promote(catalog, 29, release, archive, manifest, sums, "Egkurilov/BOOHTACORD")
    repeated = promote(catalog, 30, release, archive, manifest, sums, "Egkurilov/BOOHTACORD")

    assert repeated["catalog_revision"] == 30
