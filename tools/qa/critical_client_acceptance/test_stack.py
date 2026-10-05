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
