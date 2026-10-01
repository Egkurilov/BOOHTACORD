import base64
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from .signing import provision


class TransientSigningMaterialTests(unittest.TestCase):
    def test_failed_build_removes_only_its_temporary_keystore_and_restores_input(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment = {'RUNNER_TEMP': temporary, 'BOOHTACORD_ANDROID_KEYSTORE_BASE64': base64.b64encode(b'fixture').decode(),
                           'BOOHTACORD_ANDROID_KEYSTORE_FILE': 'existing.jks',
                           **{'BOOHTACORD_ANDROID_' + name: 'fixture' for name in ('KEYSTORE_PASSWORD', 'KEY_ALIAS', 'KEY_PASSWORD')}}
            with patch.dict(os.environ, environment), self.assertRaises(RuntimeError):
                with provision():
                    self.assertEqual(Path(os.environ['BOOHTACORD_ANDROID_KEYSTORE_FILE']).read_bytes(), b'fixture')
                    raise RuntimeError('build failed')
            self.assertEqual(list(Path(temporary).iterdir()), [])
