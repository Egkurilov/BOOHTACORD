import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from .stack import Stack


class LoopbackTransportTests(unittest.TestCase):
    def test_owned_sfu_enables_only_local_ice_candidates(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            stack = Stack(work, work)
            with patch('tools.qa.critical_client_acceptance.stack.local_docker'), \
                    patch('tools.qa.critical_client_acceptance.stack.ports_available'), \
                    patch('tools.qa.critical_client_acceptance.stack.ready'), \
                    patch('tools.qa.critical_client_acceptance.stack.Base.start'), \
                    patch.object(stack, 'container'):
                stack.start()
            config = (work/'livekit.yaml').read_text()
            self.assertIn('enable_loopback_candidate: true', config)
            self.assertIn('includes: ["lo"]', config)
            self.assertIn('bind_addresses: ["0.0.0.0"]', config)
            self.assertIn(f'http://{stack.owner}-api:8080/internal/livekit/roster', config)
            self.assertEqual(stack.environment['LIVEKIT_PRIVATE_HTTP_URL'],
                             f'http://{stack.owner}-sfu:4880')
            args = container.call_args.args
            pairs = list(zip(args, args[1:]))
            self.assertEqual(args[:2], ('sfu', IMAGE))
            self.assertTrue(container.call_args.kwargs.get('network', True))
            self.assertIn(('--publish', '127.0.0.1:4880:4880/tcp'), pairs)
            self.assertIn(('--publish', '127.0.0.1:4881:4881/tcp'), pairs)
            self.assertIn(('--publish', '127.0.0.1:4882:4882/udp'), pairs)
