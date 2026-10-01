import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from tools.release.bundle.signature import sign, verify


class SignatureTests(unittest.TestCase):
    def test_trusted_key_accepts_signature_and_rejects_tampering(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            key, public, document = [root / name for name in ("key.pem", "pub.pem", "manifest.json")]
            openssl = shutil.which("openssl") or r"C:\Program Files\Git\usr\bin\openssl.exe"
            subprocess.run([openssl, "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048", "-out", str(key)], check=True, capture_output=True)
            subprocess.run([openssl, "pkey", "-in", str(key), "-pubout", "-out", str(public)], check=True, capture_output=True)
            document.write_text('{"release_id":"immutable"}')
            sign(document, key, openssl=openssl)
            verify(document, public, openssl=openssl)
            document.write_text('{"release_id":"changed"}')
            with self.assertRaises(ValueError): verify(document, public, openssl=openssl)


if __name__ == "__main__": unittest.main()
