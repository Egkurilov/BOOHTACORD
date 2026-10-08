"""Verify immutable Windows release assets before catalog promotion."""
import hashlib
import json
import re
import zipfile
from pathlib import Path, PurePosixPath


def _checksums_text(text):
    records = {}
    for line in text.splitlines():
        match = re.fullmatch(r"([0-9a-fA-F]{64})  (.+)", line)
        if not match or match[2] in records:
            raise ValueError("invalid or duplicate checksum entry")
        records[match[2]] = match[1].lower()
    return records


def _checksums(path):
    return _checksums_text(path.read_text(encoding="utf-8-sig"))


def _digest_file(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def verify_release(release, archive, manifest_path, checksums_path, repository):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("invalid repository")
    manifest_bytes = Path(manifest_path).read_bytes()
    manifest = json.loads(manifest_bytes)
    archive = Path(archive)
    checksums = _checksums(Path(checksums_path))
    if set(checksums) != {archive.name, Path(manifest_path).name}:
        raise ValueError("release checksum list contains unexpected assets")
    for path in (archive, Path(manifest_path)):
        if checksums.get(path.name) != _digest_file(path):
            raise ValueError("release asset checksum mismatch")
    version, separator, build = manifest.get("version", "").partition("+")
    order = manifest.get("release_order")
    if (manifest.get("schema_version") != 1 or manifest.get("platform") != "windows"
            or manifest.get("architectures") != ["x64"] or not separator
            or not re.fullmatch(r"\d+\.\d+\.\d+", version) or not build.isdigit()
            or manifest.get("native_build", build) != build
            or type(order) is not int or order < 1
            or manifest.get("release_id") != f"windows-direct-stable-r{order}"):
        raise ValueError("Windows x64 release manifest identity is invalid")
    tag = f"windows-v{version}"
    if (release.get("tag_name") != tag or release.get("draft") is not False
            or release.get("prerelease") is not False
            or not isinstance(release.get("published_at"), str)
            or not re.fullmatch(r"\d{4}-\d\d-\d\dT[^\s]+Z", release["published_at"])):
        raise ValueError("release is not a published stable Windows version")
    expected = manifest.get("files")
    if not isinstance(expected, dict) or not expected:
        raise ValueError("release manifest has no file inventory")
    with zipfile.ZipFile(archive) as package:
        names = [item.filename for item in package.infolist() if not item.is_dir()]
        if len(names) != len(set(names)) or set(names) != set(expected) | {"artifact-manifest.json"}:
            raise ValueError("archive contents differ from release manifest")
        if package.read("artifact-manifest.json") != manifest_bytes:
            raise ValueError("archive manifest differs from published manifest")
        for name, metadata in expected.items():
            path = PurePosixPath(name)
            if "\\" in name or path.is_absolute() or any(part in ("", ".", "..") for part in path.parts):
                raise ValueError("unsafe path in release manifest")
            digest = hashlib.sha256()
            size = 0
            with package.open(name) as payload:
                while chunk := payload.read(1024 * 1024):
                    size += len(chunk)
                    digest.update(chunk)
            if (metadata.get("bytes") != size
                    or not re.fullmatch(r"[0-9a-f]{64}", metadata.get("sha256", ""))
                    or metadata["sha256"] != digest.hexdigest()):
                raise ValueError("archive file differs from release manifest")
    url = f"https://github.com/{repository}/releases/tag/{tag}"
    return {"release_id": manifest["release_id"], "release_order": order,
            "version": version, "native_build": build, "priority": "normal",
            "published_at": release["published_at"],
            "summary": f"BOOHTACORD Windows {version} build {build}.",
            "release_notes_url": url, "requirements": {"supported_arches": ["x64"]},
            "action": {"kind": "open_download_page", "url": url}}
