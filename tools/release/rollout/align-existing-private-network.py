#!/usr/bin/env python3
"""Match deployment IPAM and proxy trust to an already active private network."""
import ipaddress
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from postgres_network import ensure_current_postgres_alias, ensure_postgres_connected, load_compose_configuration


def output(*command):
    return subprocess.check_output(command, text=True, stderr=subprocess.DEVNULL).strip()


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
    if len(sys.argv) == 3 and sys.argv[2] == "--ensure-postgres-alias":
        try:
            ensure_current_postgres_alias(sys.argv[1])
        except (OSError, ValueError, TypeError, KeyError, RuntimeError, subprocess.CalledProcessError,
                json.JSONDecodeError) as error:
            detail = str(error) if isinstance(error, RuntimeError) else type(error).__name__
            print(f"Could not safely restore the PostgreSQL service alias: {detail}.", file=sys.stderr)
            raise SystemExit(1)
        raise SystemExit(0)
    if len(sys.argv) != 4:
        raise SystemExit("usage: align-existing-private-network.py PROJECT_DIR CANONICAL_ENV RECOVERY_COMPOSE")
    try:
        raise SystemExit(main(sys.argv[1], sys.argv[2], sys.argv[3]))
    except (OSError, ValueError, TypeError, KeyError, RuntimeError, subprocess.CalledProcessError, json.JSONDecodeError):
        print("Could not safely align deployment settings to the active private network.", file=sys.stderr)
        raise SystemExit(1)
