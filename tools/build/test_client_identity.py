import json
from pathlib import Path
from tools.build.client_identity import dart_defines, load


def fixture(tmp_path: Path):
    (tmp_path / "contracts").mkdir()
    (tmp_path / "clients/flutter").mkdir(parents=True)
    value = {
        "schema_version": 2,
        "application_family": "boohtacord",
        "builds": {
            "web": {"platform":"web","distribution":"browser","channel":"stable","arch":"any","release_id":"web-2","release_order":2,"version":"2.0.0","native_build":None},
            "android": {"platform":"android","distribution":"direct","channel":"stable","arch":"any","release_id":"android-4","release_order":4,"version":"2.0.0","native_build":"4"},
        },
    }
    (tmp_path / "contracts/client-build.json").write_text(json.dumps(value), encoding="utf-8")
    (tmp_path / "clients/flutter/pubspec.yaml").write_text("version: 2.0.0+4\n", encoding="utf-8")
    return value


def test_identity_drives_dart_defines(tmp_path):
    value = fixture(tmp_path)
    assert load("web", tmp_path) == value["builds"]["web"]
    assert load("android", tmp_path) == value["builds"]["android"]
    defines = dart_defines("android", tmp_path)
    assert "--dart-define=APP_RELEASE_ID=android-4" in defines
    assert "--dart-define=APP_DISTRIBUTION=direct" in defines


def test_identity_rejects_pubspec_drift(tmp_path):
    fixture(tmp_path)
    (tmp_path / "clients/flutter/pubspec.yaml").write_text("version: 2.0.1+5\n", encoding="utf-8")
    try: load("android", tmp_path)
    except ValueError as error: assert "differs" in str(error)
    else: raise AssertionError("version drift accepted")


def test_web_identity_has_no_native_build(tmp_path):
    fixture(tmp_path)
    assert load("web", tmp_path)["native_build"] is None
