"""Refuse remote Docker PIDs and the host namespace before any iptables call."""
import unittest
from types import SimpleNamespace
from unittest.mock import patch
from .restrict import restrict


class NamespaceSafetyTest(unittest.TestCase):
    @patch('tools.network.restricted.restrict.subprocess.run')
    @patch('tools.network.restricted.restrict.subprocess.check_output', return_value='tcp://remote:2376')
    @patch('tools.network.restricted.restrict.os.name', 'posix')
    @patch.dict('os.environ', {'DOCKER_HOST': '', 'DOCKER_CONTEXT': ''})
    def test_remote_context_rejected(self, read, run):
        with self.assertRaisesRegex(RuntimeError, 'local rootful'):
            restrict('restricted-network-owned', 'udp-blocked')
        run.assert_not_called()

    @patch('tools.network.restricted.restrict.subprocess.run')
    @patch('tools.network.restricted.restrict.Path.stat', return_value=SimpleNamespace(st_ino=1))
    @patch('tools.network.restricted.restrict.subprocess.check_output', side_effect=['unix:///var/run/docker.sock', '1234'])
    @patch('tools.network.restricted.restrict.os.name', 'posix')
    @patch.dict('os.environ', {'DOCKER_HOST': '', 'DOCKER_CONTEXT': ''})
    def test_host_namespace_rejected(self, read, stat, run):
        with self.assertRaisesRegex(RuntimeError, 'host network namespace'):
            restrict('restricted-network-owned', 'signal-only')
        run.assert_not_called()

    @patch('tools.network.restricted.restrict.subprocess.run')
    @patch('tools.network.restricted.restrict.os.geteuid', return_value=0, create=True)
    @patch('tools.network.restricted.restrict.Path.stat', side_effect=[SimpleNamespace(st_ino=2), SimpleNamespace(st_ino=1)])
    @patch('tools.network.restricted.restrict.subprocess.check_output', side_effect=['unix:///var/run/docker.sock', '1234'])
    @patch('tools.network.restricted.restrict.os.name', 'posix')
    @patch.dict('os.environ', {'DOCKER_HOST': '', 'DOCKER_CONTEXT': ''})
    def test_only_owned_namespace_is_modified(self, read, stat, uid, run):
        restrict('restricted-network-owned', 'udp-blocked')
        run.assert_called_once_with(['nsenter', '--target', '1234', '--net', 'iptables', '-I', 'INPUT', '-p', 'udp', '-j', 'DROP'], check=True)
