import unittest
from unittest.mock import patch
from .rollout import transition


class RollbackTransitionTests(unittest.TestCase):
    def test_interruption_restores_current_while_identity_agrees(self):
        with patch('tools.release.rollback.rollout.identities', return_value={'id': 'same'}), \
             patch('tools.release.rollback.rollout.apply', side_effect=[KeyboardInterrupt(), None]) as apply:
            with self.assertRaises(KeyboardInterrupt):
                transition('previous', {}, 'current', {}, 'host.env')
            self.assertEqual([call.args[0] for call in apply.call_args_list], ['previous', 'current'])

    def test_failed_previous_rollout_restores_current_once(self):
        with patch('tools.release.rollback.rollout.identities', return_value={'volume': 'same'}), \
             patch('tools.release.rollback.rollout.apply', side_effect=[RuntimeError('unhealthy'), None]) as apply:
            with self.assertRaisesRegex(RuntimeError, 'unhealthy'):
                transition('previous', {}, 'current', {}, 'host.env')
            self.assertEqual([call.args[0] for call in apply.call_args_list], ['previous', 'current'])

    def test_identity_drift_blocks_automatic_restore(self):
        with patch('tools.release.rollback.rollout.identities', side_effect=[{'id': 'old'}, {'id': 'changed'}]), \
             patch('tools.release.rollback.rollout.apply', side_effect=RuntimeError('unhealthy')) as apply:
            with self.assertRaisesRegex(RuntimeError, 'identity changed'):
                transition('previous', {}, 'current', {}, 'host.env')
            self.assertEqual(apply.call_count, 1)

    def test_successful_rehearsal_returns_to_current(self):
        with patch('tools.release.rollback.rollout.identities', return_value={'id': 'same'}), \
             patch('tools.release.rollback.rollout.apply') as apply, \
             patch('tools.release.rollback.rollout.time.sleep'):
            transition('previous', {}, 'current', {}, 'host.env', rehearse=True, observe=30)
            self.assertEqual([call.args[0] for call in apply.call_args_list], ['previous', 'current'])

    def test_failed_restore_is_not_retried_implicitly(self):
        with patch('tools.release.rollback.rollout.identities', return_value={'id': 'same'}), \
             patch('tools.release.rollback.rollout.apply', side_effect=[None, RuntimeError('restore failed')]) as apply, \
             patch('tools.release.rollback.rollout.time.sleep'):
            with self.assertRaisesRegex(RuntimeError, 'restore failed'):
                transition('previous', {}, 'current', {}, 'host.env', rehearse=True, observe=30)
            self.assertEqual(apply.call_count, 2)
