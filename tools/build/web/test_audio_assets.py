import hashlib
import unittest
from .audio_assets import verify_wasm


class ReleaseAudioAssetTests(unittest.TestCase):
    def test_rejects_html_and_corrupted_wasm_even_with_success_status(self):
        wasm = b'\0asm fixture'
        checksum = hashlib.sha256(wasm).hexdigest()
        verify_wasm('application/wasm', wasm, checksum)
        for mime, data in [('text/html', wasm), ('application/wasm', b'<!doctype html>'), ('application/wasm', wasm + b'corrupt')]:
            with self.subTest(mime=mime):
                with self.assertRaises(ValueError): verify_wasm(mime, data, checksum)
