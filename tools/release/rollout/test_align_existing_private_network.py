import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("align-existing-private-network.py")
sys.path.insert(0, str(SCRIPT.parent))
POSTGRES = importlib.import_module("postgres_network")
SPEC = importlib.util.spec_from_file_location("align_private_network", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class AlignPostgresNetworkTests(unittest.TestCase):
    def test_recovery_config_includes_operator_profile(self):
        with patch.object(POSTGRES, "output", return_value='{"services": {}}') as output:
            configuration = MODULE.load_compose_configuration(["docker", "compose"])

        self.assertEqual(configuration, {"services": {}})
        output.assert_called_once_with(
            "docker", "compose", "--profile", "operator", "config", "--format", "json"
        )

    def test_recovery_compose_reuses_private_network_as_external(self):
        configuration = {
            "services": {"api": {"image": "api-ref"}},
            "networks": {"private": {"internal": True, "ipam": {"config": []}}, "edge": {}},
            "volumes": {"postgres-data": {}},
        }
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "recovery.yaml"
            destination.touch()
            MODULE.write_external_network_config(configuration, destination, "voice-platform_private")
            written = json.loads(destination.read_text(encoding="utf-8"))

        self.assertEqual(written["networks"]["private"], {
            "external": True, "name": "voice-platform_private"
        })
        self.assertIn("api", written["services"])
        self.assertIn("postgres-data", written["volumes"])

    def test_attaches_detached_project_postgres_container(self):
        with patch.object(POSTGRES, "output", side_effect=[
            "postgres-id",
            '{"com.docker.compose.project":"voice-platform","com.docker.compose.service":"postgres"}',
            "{}",
        ]), patch.object(MODULE.subprocess, "run") as run:
            MODULE.ensure_postgres_connected([], "voice-platform", "voice-platform_private")

        run.assert_called_once_with(
            ["docker", "network", "connect", "--alias", "postgres",
             "voice-platform_private", "postgres-id"],
            check=True,
            stdout=MODULE.subprocess.DEVNULL,
            stderr=MODULE.subprocess.DEVNULL,
        )

    def test_restores_service_alias_on_attached_postgres_container(self):
        with patch.object(POSTGRES, "output", side_effect=[
            "postgres-id",
            '{"com.docker.compose.project":"voice-platform","com.docker.compose.service":"postgres"}',
            '{"voice-platform_private":{"IPAddress":"172.30.254.3","Aliases":["voice-platform-postgres-1"]}}',
        ]), patch.object(MODULE.subprocess, "run") as run:
            MODULE.ensure_postgres_connected([], "voice-platform", "voice-platform_private")

        self.assertEqual(run.call_count, 2)
        run.assert_any_call(
            ["docker", "network", "disconnect", "voice-platform_private", "postgres-id"],
            check=True,
            stdout=MODULE.subprocess.DEVNULL,
            stderr=MODULE.subprocess.DEVNULL,
        )
        run.assert_any_call(
            ["docker", "network", "connect", "--alias", "postgres", "voice-platform_private", "postgres-id"],
            check=True,
            stdout=MODULE.subprocess.DEVNULL,
            stderr=MODULE.subprocess.DEVNULL,
        )

    def test_restores_service_alias_when_docker_returns_null_aliases(self):
        with patch.object(POSTGRES, "output", side_effect=[
            "postgres-id",
            '{"com.docker.compose.project":"voice-platform","com.docker.compose.service":"postgres"}',
            '{"voice-platform_private":{"IPAddress":"172.30.254.3","Aliases":null}}',
        ]), patch.object(MODULE.subprocess, "run") as run:
            MODULE.ensure_postgres_connected([], "voice-platform", "voice-platform_private")

        self.assertEqual(run.call_count, 2)

    def test_does_not_reconnect_postgres_with_service_alias(self):
        with patch.object(POSTGRES, "output", side_effect=[
            "postgres-id",
            '{"com.docker.compose.project":"voice-platform","com.docker.compose.service":"postgres"}',
            '{"voice-platform_private":{"IPAddress":"172.30.254.3","Aliases":["postgres"]}}',
        ]), patch.object(MODULE.subprocess, "run") as run:
            MODULE.ensure_postgres_connected([], "voice-platform", "voice-platform_private")

        run.assert_not_called()

    def test_rejects_container_from_another_compose_service(self):
        with patch.object(POSTGRES, "output", side_effect=[
            "unexpected-id",
            '{"com.docker.compose.project":"voice-platform","com.docker.compose.service":"api"}',
        ]), patch.object(MODULE.subprocess, "run") as run:
            with self.assertRaises(RuntimeError):
                MODULE.ensure_postgres_connected([], "voice-platform", "voice-platform_private")

        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
