import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch
from .cleanup import cleanup


class CleanupTests(unittest.TestCase):
    def test_attempts_every_owned_resource_after_a_failure(self):
        stack = SimpleNamespace(stop_api=Mock(), api=None, owner='private-owner',
                                resources=[('container', 'one'), ('container', 'two'), ('network', 'three')])
        with patch('tools.load.controller.cleanup.remove_owned', side_effect=[ValueError('foreign'), None, None]) as remove:
            report = cleanup(stack)
        self.assertEqual(remove.call_count, 3)
        self.assertFalse(report['owned_resources_removed'])
        self.assertEqual(report['cleanup_failures'], 1)
        self.assertNotIn('private-owner', str(report))
        self.assertEqual(stack.resources, [('network', 'three')])


if __name__ == '__main__':
    unittest.main()
