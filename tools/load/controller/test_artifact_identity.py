import hashlib
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from .artifact_identity import api_binary_sha256


class ArtifactIdentityTests(unittest.TestCase):
    def test_hashes_binary_copied_from_owned_api_container(self):
        stack = SimpleNamespace()
        expected_binary = b'owned api binary'
        with tempfile.TemporaryDirectory() as directory, \
                patch('tools.load.controller.artifact_identity.owned', return_value='qa-client-0123456789abcdef-api') as owned, \
                patch('tools.load.controller.artifact_identity.run') as run:
            def copy_binary(*arguments, **options):
                self.assertEqual(arguments[:3], (
                    'docker', 'cp', 'qa-client-0123456789abcdef-api:/api'))
                Path(arguments[3]).write_bytes(expected_binary)

            run.side_effect = copy_binary
            result = api_binary_sha256(stack, Path(directory))

        owned.assert_called_once_with(stack, 'api')
        self.assertEqual(result, hashlib.sha256(expected_binary).hexdigest())


if __name__ == '__main__':
    unittest.main()
