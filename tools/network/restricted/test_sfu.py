"""Transport restrictions are owned by a disposable fixture, never host policy."""
import unittest
from .sfu import command
from .restrict import rules


class RestrictionsTest(unittest.TestCase):
    def test_mapping_boundary(self):
        baseline = command('owned', 'baseline')
        self.assertIn('127.0.0.1:7882:7882/udp', baseline)
        self.assertIn('127.0.0.1:17881:17881/tcp', baseline)
        udp_blocked = command('owned', 'udp-blocked')
        self.assertNotIn('127.0.0.1:7882:7882/udp', udp_blocked)
        self.assertIn('127.0.0.1:17881:17881/tcp', udp_blocked)
        signal_only = command('owned', 'signal-only')
        self.assertNotIn('127.0.0.1:17881:17881/tcp', signal_only)
        self.assertNotIn('127.0.0.1:7882:7882/udp', signal_only)
        self.assertIn('127.0.0.1:17880:7880/tcp', signal_only)
        self.assertNotIn('--privileged', baseline)
        self.assertIn('--rm', baseline)

    def test_unknown_profile_rejected(self):
        with self.assertRaises(ValueError):
            command('owned', 'production')

    def test_namespace_filters_cover_direct_container_candidates(self):
        self.assertEqual(rules('baseline'), [])
        self.assertEqual(rules('udp-blocked'), [['-p', 'udp', '-j', 'DROP']])
        self.assertEqual(rules('signal-only'), [['-p', 'udp', '-j', 'DROP'],
                                               ['-p', 'tcp', '--dport', '17881', '-j', 'DROP']])
