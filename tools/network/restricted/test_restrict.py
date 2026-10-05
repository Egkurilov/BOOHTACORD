"""Fail closed before policy changes; pin the verified namespace across PID reuse."""
import unittest
from types import SimpleNamespace
from unittest.mock import patch
from .restrict import restrict


class NamespaceSafetyTest(unittest.TestCase):
    def invoke(self, outputs, namespace=2, uid=0):
        patches = [patch('tools.network.restricted.restrict.os.name', 'posix'),
                   patch.dict('os.environ', {'DOCKER_HOST': '', 'DOCKER_CONTEXT': ''}),
                   patch('tools.network.restricted.restrict.os.geteuid', return_value=uid, create=True),
                   patch('tools.network.restricted.restrict.os.getpid', return_value=99),
                   patch('tools.network.restricted.restrict.os.open', return_value=42),
                   patch('tools.network.restricted.restrict.os.close'),
                   patch('tools.network.restricted.restrict.os.fstat', return_value=SimpleNamespace(st_ino=namespace)),
                   patch('tools.network.restricted.restrict.Path.stat', return_value=SimpleNamespace(st_ino=1)),
                   patch('tools.network.restricted.restrict.subprocess.check_output', side_effect=outputs),
                   patch('tools.network.restricted.restrict.subprocess.run')]
        mocks = [item.start() for item in patches]
        for item in patches:
            self.addCleanup(item.stop)
        return mocks[-1]

    def test_remote_context_rejected(self):
        run = self.invoke(['tcp://remote:2376'])
        with self.assertRaisesRegex(RuntimeError, 'local rootful'):
            restrict('restricted-network-owned', 'udp-blocked')
        run.assert_not_called()

    def test_host_namespace_rejected(self):
        run = self.invoke(['unix:///var/run/docker.sock', 'restricted-networks', '1234'], namespace=1)
        with self.assertRaisesRegex(RuntimeError, 'host network namespace'):
            restrict('restricted-network-owned', 'signal-only')
        run.assert_not_called()

    def test_unowned_container_rejected(self):
        run = self.invoke(['unix:///var/run/docker.sock', 'other-packet'])
        with self.assertRaisesRegex(RuntimeError, 'unowned'):
            restrict('restricted-network-owned', 'udp-blocked')
        run.assert_not_called()

    def test_verified_namespace_is_pinned(self):
        run = self.invoke(['unix:///var/run/docker.sock', 'restricted-networks', '1234'])
        restrict('restricted-network-owned', 'udp-blocked')
        run.assert_called_once_with(['nsenter', '--net=/proc/99/fd/42', 'iptables', '-I', 'INPUT', '-p', 'udp', '-j', 'DROP'], check=True)

    def test_non_root_uses_bounded_root_helper(self):
        run = self.invoke(['unix:///var/run/docker.sock'], uid=1000)
        restrict('restricted-network-owned', 'udp-blocked')
        self.assertEqual(run.call_args.args[0][:2], ['sudo', '-n'])
        self.assertEqual(run.call_args.args[0][-3:], ['tools.network.restricted.restrict', 'restricted-network-owned', 'udp-blocked'])
