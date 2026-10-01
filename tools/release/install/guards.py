"""Fail closed before installation and before declaring a release healthy."""
from tools.release.bundle.manifest import require


def disk_budget(available, payload_bytes):
    require(payload_bytes > 0, "Empty release bundle")
    require(available >= payload_bytes * 4 + 2_147_483_648,
            "Insufficient space for extraction, image import and protected reserve")


def installed_digests(expected, loaded, running, configured, service):
    require(loaded == expected, service + " loaded image differs from verified OCI index")
    require(running == expected, service + " running image differs from verified OCI index")
    require(configured == f"voice-platform-{service}@{expected}", service + " does not use the pinned digest")
