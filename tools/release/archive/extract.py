"""Bounded extraction; reject links, special files, aliases and path traversal."""
import shutil
import tarfile
from pathlib import Path, PurePosixPath


def extract(archive: Path, destination: Path, *, max_bytes: int):
    destination.mkdir(parents=True, exist_ok=False)
    root = destination.resolve()
    seen, total = set(), 0
    with tarfile.open(archive, "r:*") as stream:
        entries = stream.getmembers()
        if len(entries) > 100_000:
            raise ValueError("Too many archive members")
        for entry in entries:
            name = PurePosixPath(entry.name)
            if name.is_absolute() or ".." in name.parts or "\\" in entry.name or ":" in entry.name:
                raise ValueError("Unsafe archive path")
            path = root.joinpath(*name.parts)
            if path == root or not path.is_relative_to(root) or path in seen:
                raise ValueError("Duplicate/invalid archive path")
            if not (entry.isfile() or entry.isdir()):
                raise ValueError("Archive links/special files are forbidden")
            seen.add(path)
            total += entry.size
            if total > max_bytes:
                raise ValueError("Archive exceeds expansion limit")
        for entry in entries:
            path = root.joinpath(*PurePosixPath(entry.name).parts)
            if entry.isdir():
                path.mkdir(parents=True, exist_ok=True)
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                with stream.extractfile(entry) as source, path.open("xb") as target:
                    shutil.copyfileobj(source, target)
                path.chmod(0o755 if entry.mode & 0o111 else 0o644)
