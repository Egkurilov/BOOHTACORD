import json
from tools.release.client_updates.catalog import mutate


def source(tmp_path):
    path = tmp_path / "catalog.json"
    path.write_text(json.dumps({"schema_version":1,"catalog_revision":4,"application_family":"boohtacord","entries":[{"platform":"windows","distribution":"direct","channel":"stable","arch":"x64","state":"unconfigured","target":None}]}), encoding="utf-8")
    return path


def target():
    return {"release_id":"windows-5","release_order":5,"version":"1.0.0","native_build":"5","priority":"normal","published_at":"2026-10-02T18:00:00Z","summary":"Windows","release_notes_url":"/releases/windows-5","requirements":{"supported_arches":["x64"]},"action":{"kind":"open_download_page","url":"/downloads/windows-5"}}


def test_promote_and_withdraw_are_revision_guarded(tmp_path):
    path = source(tmp_path); selector = ("windows","direct","stable","x64")
    mutate(path, 4, selector, "published", target())
    promoted = json.loads(path.read_text(encoding="utf-8"))
    assert promoted["catalog_revision"] == 5 and promoted["entries"][0]["state"] == "published"
    mutate(path, 5, selector, "unconfigured", None)
    assert json.loads(path.read_text(encoding="utf-8"))["catalog_revision"] == 6


def test_rejects_stale_revision(tmp_path):
    path = source(tmp_path)
    try: mutate(path, 3, ("windows","direct","stable","x64"), "published", target())
    except ValueError as error: assert "revision" in str(error)
    else: raise AssertionError("stale writer accepted")
