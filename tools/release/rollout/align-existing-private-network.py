#!/usr/bin/env python3
"""Match deployment IPAM and proxy trust to an already active private network."""
import ipaddress
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


def output(*command):
    return subprocess.check_output(command, text=True, stderr=subprocess.DEVNULL).strip()


def load_compose_configuration(compose):
    return json.loads(output(*compose, "--profile", "operator", "config", "--format", "json"))


def ensure_postgres_connected(compose, project, network_name):
    containers = output(*compose, "ps", "-aq", "postgres").splitlines()
    if len(containers) != 1:
        raise RuntimeError("expected exactly one PostgreSQL service container")
    container_id = containers[0]
    labels = json.loads(output("docker", "inspect", "--format", "{{json .Config.Labels}}", container_id))
    if (labels.get("com.docker.compose.project") != project
            or labels.get("com.docker.compose.service") != "postgres"):
        raise RuntimeError("PostgreSQL container identity does not match the Compose project")
    networks = json.loads(output("docker", "inspect", "--format", "{{json .NetworkSettings.Networks}}", container_id))
    if network_name not in networks:
        subprocess.run(["docker", "network", "connect", network_name, container_id], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("Reattached the existing PostgreSQL container to the active private network.")


def write_external_network_config(configuration, destination, network_name):
    networks = configuration.get("networks", {})
    if not isinstance(networks.get("private"), dict):
        raise RuntimeError("Compose private network configuration is unavailable")
    networks["private"] = {"external": True, "name": network_name}
    destination = Path(destination)
    if destination.is_symlink() or not destination.is_file():
        raise RuntimeError("recovery Compose file is unavailable")
    os.chmod(destination, 0o600)
    destination.write_text(json.dumps(configuration), encoding="utf-8")


def update_environment(path, values):
    path = Path(path)
    if path.is_symlink() or not path.is_file():
        raise RuntimeError("deployment environment is unavailable")
    existing = path.read_text(encoding="utf-8").splitlines()
    retained = [line for line in existing if not any(line.startswith(key + "=") for key in values)]
    content = "\n".join(retained + [f"{key}={value}" for key, value in values.items()]) + "\n"
    descriptor, temporary = tempfile.mkstemp(prefix=".env.network.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as target:
            target.write(content)
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main(project_dir, canonical_env, recovery_compose):
    project_dir = Path(project_dir).resolve()
    compose_dir = project_dir / "deploy" if (project_dir / "deploy/compose.yaml").is_file() else project_dir
    compose = ["docker", "compose", "--project-directory", str(compose_dir), "--env-file",
               str(project_dir / ".env"), "-f", str(compose_dir / "compose.yaml")]
    configuration = load_compose_configuration(compose)
    project = configuration.get("name", "voice-platform")
    network_name = project + "_private"
    network = json.loads(output("docker", "network", "inspect", network_name, "--format", "{{json .IPAM.Config}}"))
    subnet = next((item.get("Subnet", "") for item in network if ":" not in item.get("Subnet", "")), "")
    if not subnet:
        raise RuntimeError("active private network has no IPv4 subnet")
    network_range = ipaddress.ip_network(subnet, strict=False)
    proxy_id = output("docker", "compose", *compose[2:], "ps", "-q", "proxy")
    if not proxy_id or "\n" in proxy_id:
        raise RuntimeError("proxy container is unavailable")
    endpoints = json.loads(output("docker", "inspect", "--format", "{{json .NetworkSettings.Networks}}", proxy_id))
    proxy_ip = endpoints.get(network_name, {}).get("IPAddress", "")
    if ipaddress.ip_address(proxy_ip) not in network_range:
        raise RuntimeError("proxy address is outside the active private subnet")
    values = {"PRIVATE_NETWORK_SUBNET": subnet, "PRIVATE_PROXY_IP": proxy_ip,
              "TRUSTED_PROXY_CIDRS": proxy_ip + "/32"}
    update_environment(project_dir / ".env", values)
    canonical_env = Path(canonical_env).resolve()
    if canonical_env != (project_dir / ".env").resolve():
        update_environment(canonical_env, values)
    ensure_postgres_connected(compose, project, network_name)
    write_external_network_config(configuration, recovery_compose, network_name)
    print("Recovery Compose configuration will reuse the active private network.")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: align-existing-private-network.py PROJECT_DIR CANONICAL_ENV RECOVERY_COMPOSE")
    try:
        raise SystemExit(main(sys.argv[1], sys.argv[2], sys.argv[3]))
    except (OSError, ValueError, TypeError, KeyError, RuntimeError, subprocess.CalledProcessError, json.JSONDecodeError):
        print("Could not safely align deployment settings to the active private network.", file=sys.stderr)
        raise SystemExit(1)
