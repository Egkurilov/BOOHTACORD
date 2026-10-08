"""Restore PostgreSQL's Compose network endpoint and service DNS alias."""
import json
import subprocess
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
    endpoint = networks.get(network_name)
    if endpoint is None:
        connect(network_name, container_id)
        print("Reattached PostgreSQL with its Compose service alias.")
    elif "postgres" not in endpoint.get("Aliases", []):
        subprocess.run(["docker", "network", "disconnect", network_name, container_id], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        connect(network_name, container_id)
        print("Restored the PostgreSQL Compose service alias on the active private network.")


def connect(network_name, container_id):
    subprocess.run(["docker", "network", "connect", "--alias", "postgres", network_name, container_id],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def ensure_current_postgres_alias(project_dir):
    project_dir = Path(project_dir).resolve()
    compose_dir = project_dir / "deploy" if (project_dir / "deploy/compose.yaml").is_file() else project_dir
    compose = ["docker", "compose", "--project-directory", str(compose_dir), "--env-file",
               str(project_dir / ".env"), "-f", str(compose_dir / "compose.yaml")]
    configuration = load_compose_configuration(compose)
    project = configuration.get("name", "voice-platform")
    ensure_postgres_connected(compose, project, project + "_private")
