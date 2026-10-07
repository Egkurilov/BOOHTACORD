"""Check private LiveKit wiring and hashes recorded in its evidence."""
import hashlib
import json
from pathlib import Path

import yaml

from .model import validate


def read(root, path):
    with (root / path).open(encoding="utf-8") as source:
        return yaml.safe_load(source)


def main():
    root = Path(__file__).resolve().parents[3]
    livekit = read(root, "deploy/livekit/livekit.yaml")
    deploy = read(root, "deploy/compose.yaml")
    deploy["services"].update(read(root, "deploy/livekit/compose.yaml")["services"])
    deploy["networks"].update(read(root, "deploy/livekit/compose.yaml").get("networks", {}))
    observability = read(root, "docker/observability/compose.yaml")
    prometheus = read(root, "docker/observability/prometheus.yaml")
    alerts = read(root, "docker/observability/livekit-network-alerts.yaml")
    validate(livekit, deploy, observability, prometheus, alerts)
    evidence_path = root / "evidence/media/livekit-network-config-2026-10-07.json"
    evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
    for path, expected in evidence["repository_artifacts"].items():
        actual = hashlib.sha256((root / path).read_bytes()).hexdigest()
        if expected != f"sha256:{actual}":
            raise ValueError(f"repository artifact hash differs for {path}")
    print("LiveKit media ports, internal scrape network, allowlist, and alert are valid")


if __name__ == "__main__":
    main()
