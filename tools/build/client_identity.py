"""Shared client release identity for web and native build commands."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(root=ROOT):
    identity = json.loads((root / "contracts/client-build.json").read_text(encoding="utf-8"))
    required = {"schema_version", "application_family", "release_id", "release_order", "version", "native_build", "channel"}
    if set(identity) != required or identity["schema_version"] != 1 or identity["application_family"] != "boohtacord":
        raise ValueError("Invalid client build identity")
    if not re.fullmatch(r"[A-Za-z0-9._-]{1,96}", identity["release_id"]):
        raise ValueError("Invalid client release ID")
    manifest = (root / "clients/flutter/pubspec.yaml").read_text(encoding="utf-8")
    expected = f'version: {identity["version"]}+{identity["native_build"]}'
    if expected not in manifest:
        raise ValueError("Flutter version differs from client build identity")
    return identity


def dart_defines(root=ROOT):
    identity = load(root)
    names = {"APP_RELEASE_ID":"release_id", "APP_RELEASE_ORDER":"release_order", "APP_VERSION":"version", "APP_NATIVE_BUILD":"native_build"}
    return tuple(f'--dart-define={name}={identity[key]}' for name, key in names.items())
