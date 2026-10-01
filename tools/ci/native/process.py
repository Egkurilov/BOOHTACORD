"""Shared process boundary for the native check entrypoints."""
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
VERSIONS = json.loads((ROOT / "tools/toolchains.json").read_text(encoding="utf-8"))


def client(name):
    path = ROOT / "clients" / name
    return path if (path / ("package.json" if name == "web" else "pubspec.yaml")).exists() else ROOT / {
        "web": "frontend", "flutter": "desktop"
    }[name]


def run(*args, cwd=ROOT, stdout=None, check=True):
    executable = shutil.which(args[0])
    if not executable:
        raise RuntimeError(f"Required executable is unavailable: {args[0]}")
    return subprocess.run([executable, *args[1:]], cwd=cwd, stdout=stdout, check=check)


def output(*args, cwd=ROOT):
    executable = shutil.which(args[0])
    if not executable:
        raise RuntimeError(f"Required executable is unavailable: {args[0]}")
    return subprocess.check_output([executable, *args[1:]], cwd=cwd, text=True).strip()


def require_version(kind, actual):
    if actual != VERSIONS[kind]:
        raise RuntimeError(f"{kind} {actual} differs from pinned {VERSIONS[kind]}")
