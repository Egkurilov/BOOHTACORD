"""Platform-specific client release identities used by every build path."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIELDS = {"platform", "distribution", "channel", "arch", "release_id", "release_order", "version", "native_build"}


def load(platform, root=ROOT):
    document = json.loads((root / "contracts/client-build.json").read_text(encoding="utf-8"))
    if set(document) != {"schema_version", "application_family", "builds"}:
        raise ValueError("Invalid client build identity envelope")
    if document["schema_version"] != 2 or document["application_family"] != "boohtacord":
        raise ValueError("Invalid client build identity version")
    identity = document["builds"].get(platform)
    if not isinstance(identity, dict) or set(identity) != FIELDS or identity["platform"] != platform:
        raise ValueError("Client platform identity is unavailable")
    if not re.fullmatch(r"[A-Za-z0-9._-]{1,96}", identity["release_id"]):
        raise ValueError("Invalid client release ID")
    if not isinstance(identity["release_order"], int) or identity["release_order"] < 1:
        raise ValueError("Invalid client release order")
    if platform == "web":
        if identity["native_build"] is not None:
            raise ValueError("Web identity cannot have a native build")
    else:
        expected = f'version: {identity["version"]}+{identity["native_build"]}'
        manifest = (root / "clients/flutter/pubspec.yaml").read_text(encoding="utf-8")
        if expected not in manifest:
            raise ValueError("Flutter version differs from client build identity")
    return identity


def dart_defines(platform, root=ROOT):
    identity = load(platform, root)
    names = {
        "APP_RELEASE_ID": "release_id", "APP_RELEASE_ORDER": "release_order",
        "APP_VERSION": "version", "APP_NATIVE_BUILD": "native_build",
        "APP_DISTRIBUTION": "distribution", "APP_CHANNEL": "channel",
    }
    return tuple(f'--dart-define={name}={identity[key]}' for name, key in names.items())


def flutter_version_args(platform, root=ROOT):
    identity = load(platform, root)
    return (f'--build-name={identity["version"]}', f'--build-number={identity["native_build"]}')
