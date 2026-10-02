"""Validate and atomically mutate the runtime client release catalog."""
import argparse
import json
import os
import re
import tempfile
from pathlib import Path

SELECTOR = ("platform", "distribution", "channel", "arch")


def validate(document):
    if set(document) != {"schema_version", "catalog_revision", "application_family", "entries"}:
        raise ValueError("catalog fields differ from schema")
    if document["schema_version"] != 1 or document["application_family"] != "boohtacord" or not 1 <= document["catalog_revision"] <= 2_147_483_647:
        raise ValueError("invalid catalog envelope")
    entries = document["entries"]
    if not isinstance(entries, list) or len(entries) > 64:
        raise ValueError("invalid catalog entries")
    seen = set()
    for entry in entries:
        key = tuple(entry.get(name) for name in SELECTOR)
        if key in seen: raise ValueError("duplicate selector")
        seen.add(key)
        if entry.get("state") not in ("published", "unconfigured", "disabled"): raise ValueError("invalid state")
        if (entry["state"] == "published") != isinstance(entry.get("target"), dict): raise ValueError("target does not match state")
        if entry["state"] == "published": validate_target(entry["target"])
    return document


def validate_target(target):
    if not re.fullmatch(r"[A-Za-z0-9._-]{1,96}", target.get("release_id", "")) or target.get("release_order", 0) < 1:
        raise ValueError("invalid release identity")
    if target.get("priority") not in ("normal", "important"):
        raise ValueError("invalid priority")
    action = target.get("action", {})
    if action.get("kind") not in ("reload", "open_download_page", "open_store", "open_instructions"):
        raise ValueError("invalid action")


def load(path):
    if path.stat().st_size > 256 * 1024: raise ValueError("catalog exceeds size limit")
    return validate(json.loads(path.read_text(encoding="utf-8")))


def mutate(path, expected_revision, selector, state, target):
    document = load(path)
    if document["catalog_revision"] != expected_revision: raise ValueError("catalog revision changed")
    matches = [entry for entry in document["entries"] if tuple(entry[name] for name in SELECTOR) == selector]
    if len(matches) != 1: raise ValueError("selector is not configured exactly once")
    matches[0].update(state=state, target=target)
    document["catalog_revision"] += 1; validate(document)
    payload = json.dumps(document, indent=2, ensure_ascii=False) + "\n"
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as stream:
        stream.write(payload); temporary = Path(stream.name)
    os.replace(temporary, path)


def main():
    parser = argparse.ArgumentParser(); parser.add_argument("operation", choices=("validate", "promote", "withdraw")); parser.add_argument("--path", type=Path, required=True)
    parser.add_argument("--expected-revision", type=int); parser.add_argument("--selector", nargs=4); parser.add_argument("--target", type=Path)
    args = parser.parse_args()
    if args.operation == "validate": load(args.path); print("Client update catalog is valid."); return
    if args.expected_revision is None or not args.selector: parser.error("mutation requires expected revision and selector")
    target = json.loads(args.target.read_text(encoding="utf-8")) if args.operation == "promote" and args.target else None
    mutate(args.path, args.expected_revision, tuple(args.selector), "published" if target else "unconfigured", target)


if __name__ == "__main__": main()
