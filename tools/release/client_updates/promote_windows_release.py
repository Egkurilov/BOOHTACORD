"""Create one compare-and-swap Windows update catalog candidate."""
import argparse
import json
from pathlib import Path

from tools.release.client_updates.catalog import mutate
from tools.release.client_updates.windows_release_verification import verify_release


def promote(catalog_path, expected_revision, release, archive, manifest, checksums, repository):
    target = verify_release(release, archive, manifest, checksums, repository)
    return mutate(Path(catalog_path), expected_revision,
                  ("windows", "direct", "stable", "x64"), "published", target)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--expected-revision", type=int, required=True)
    parser.add_argument("--release", type=Path, required=True)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--checksums", type=Path, required=True)
    parser.add_argument("--repository", required=True)
    args = parser.parse_args()
    updated = promote(args.catalog, args.expected_revision, json.loads(args.release.read_text()),
                      args.archive, args.manifest, args.checksums, args.repository)
    if updated["catalog_revision"] == args.expected_revision:
        print(f"Windows target is already current at catalog revision {args.expected_revision}.")
    else:
        print(f"Windows update candidate created at catalog revision {updated['catalog_revision']}.")


if __name__ == "__main__":
    main()
