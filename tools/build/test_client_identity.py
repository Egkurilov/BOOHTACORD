import json
from pathlib import Path
from tools.build.client_identity import dart_defines, load


def fixture(tmp_path: Path):
    (tmp_path / "contracts").mkdir()
    (tmp_path / "clients/flutter").mkdir(parents=True)
    value = {"schema_version":1,"application_family":"boohtacord","release_id":"client-2","release_order":2,"version":"2.0.0","native_build":"4","channel":"stable"}
    (tmp_path / "contracts/client-build.json").write_text(json.dumps(value), encoding="utf-8")
    (tmp_path / "clients/flutter/pubspec.yaml").write_text("version: 2.0.0+4\n", encoding="utf-8")
    return value


def test_identity_drives_dart_defines(tmp_path):
    value = fixture(tmp_path)
    assert load(tmp_path) == value
    assert "--dart-define=APP_RELEASE_ID=client-2" in dart_defines(tmp_path)


def test_identity_rejects_pubspec_drift(tmp_path):
    fixture(tmp_path)
    (tmp_path / "clients/flutter/pubspec.yaml").write_text("version: 2.0.1+5\n", encoding="utf-8")
    try: load(tmp_path)
    except ValueError as error: assert "differs" in str(error)
    else: raise AssertionError("version drift accepted")
