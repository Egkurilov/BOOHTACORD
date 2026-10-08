"""Capacity probes must reach storage without bypassing account admission."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch
from .run import scenario


class ScenarioTests(unittest.TestCase):
    def execute(self, peer_status=507, quota_status=429):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'.out').mkdir()
            binary = root/'fixture-api'
            binary.write_bytes(b'synthetic-test-only')
            stack = Mock(binary=binary)
            client, peer = Mock(), Mock()
            held = [Mock(status=201), Mock(status=201)]
            quota, capacity, retry = Mock(status=quota_status), Mock(status=peer_status), Mock(status=201)
            client.upload.side_effect = [*held, quota, retry]
            client.create_peer.return_value = peer
            peer.upload.return_value = capacity
            with patch('tools.qa.upload_reservations.run.UploadStack', return_value=stack) as factory, \
                 patch('tools.qa.upload_reservations.run.Client', return_value=client), \
                 patch('tools.qa.upload_reservations.run.sample', return_value={}), \
                 patch('tools.qa.upload_reservations.run.await_reserved') as reserved, \
                 patch('tools.qa.upload_reservations.run.validate'), \
                 patch('tools.qa.upload_reservations.run.output', return_value='0'), \
                 patch('tools.qa.upload_reservations.run.finish', side_effect=lambda connection: connection.status) as finish:
                result = scenario(root, True)
                self.assertEqual(factory.call_args.args[-1], 2147483648+51000000)
                self.assertEqual([row.args[1] for row in reserved.call_args_list], [50000000, 25000000, 0, 0])
                client.create_peer.assert_called_once_with(stack.password)
                self.assertEqual([row.args[0].status for row in finish.call_args_list], [429, 507, 201, 201])
                peer.upload.assert_called_once_with(client.create_channel.return_value)
            stack.close.assert_called_once()
            quota.close.assert_called()
            capacity.close.assert_called()
            return result

    def test_quota_and_capacity_use_distinct_real_principals(self):
        result = self.execute()
        self.assertEqual(result['same_account_concurrency_status'], 429)
        self.assertTrue(result['capacity_account_independent'])
        self.assertEqual(result['rejection_status'], 507)

    def test_peer_429_cannot_be_reported_as_storage_acceptance(self):
        for status in (201, 403, 429, 503):
            with self.subTest(status=status), self.assertRaisesRegex(AssertionError, f'507.*{status}'):
                self.execute(peer_status=status)

    def test_relaxed_account_quota_cannot_pass(self):
        with self.assertRaisesRegex(AssertionError, '429.*201'):
            self.execute(quota_status=201)
