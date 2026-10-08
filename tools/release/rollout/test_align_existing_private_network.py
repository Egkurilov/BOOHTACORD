import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("align-existing-private-network.py")
SPEC = importlib.util.spec_from_file_location("align_private_network", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class AlignPostgresNetworkTests(unittest.TestCase):
    def test_attaches_detached_project_postgres_container(self):
        with patch.object(MODULE, "output", side_effect=[
            "postgres-id",
            '{"com.docker.compose.project":"voice-platform","com.docker.compose.service":"postgres"}',
            "{}",
        ]), patch.object(MODULE.subprocess, "run") as run:
            MODULE.ensure_postgres_connected([], "voice-platform", "voice-platform_private")

        run.assert_called_once_with(
            ["docker", "network", "connect", "voice-platform_private", "postgres-id"],
            check=True,
            stdout=MODULE.subprocess.DEVNULL,
            stderr=MODULE.subprocess.DEVNULL,
        )

    def test_does_not_reconnect_attached_postgres_container(self):
        with patch.object(MODULE, "output", side_effect=[
            "postgres-id",
            '{"com.docker.compose.project":"voice-platform","com.docker.compose.service":"postgres"}',
            '{"voice-platform_private":{"IPAddress":"172.30.254.3"}}',
        ]), patch.object(MODULE.subprocess, "run") as run:
            MODULE.ensure_postgres_connected([], "voice-platform", "voice-platform_private")

        run.assert_not_called()

    def test_rejects_container_from_another_compose_service(self):
        with patch.object(MODULE, "output", side_effect=[
            "unexpected-id",
            '{"com.docker.compose.project":"voice-platform","com.docker.compose.service":"api"}',
        ]), patch.object(MODULE.subprocess, "run") as run:
            with self.assertRaises(RuntimeError):
                MODULE.ensure_postgres_connected([], "voice-platform", "voice-platform_private")

        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
