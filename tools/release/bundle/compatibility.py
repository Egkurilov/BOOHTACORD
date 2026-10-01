"""Conservative upgrade/rollback rules; no automatic reverse database migration."""
from .manifest import require


def compatible_upgrade(current, incoming):
    old = current["compatibility"]["migrations"]
    new = incoming["compatibility"]["migrations"]
    require(all(new.get(name) == digest for name, digest in old.items()),
            "Previously applied migrations were removed or changed")
    require(sorted(new)[:len(old)] == sorted(old), "Migrations must be append-only")


def compatible_rollback(current, previous):
    for field in ("migrations", "backend_tree", "contracts_sha256", "topology_sha256"):
        require(current["compatibility"][field] == previous["compatibility"][field],
                "Rollback compatibility differs: " + field)


def applied_migrations(names, manifest):
    expected = sorted(manifest["compatibility"]["migrations"])
    require(sorted(names) == expected[:len(names)], "Database migration history is not a release prefix")
