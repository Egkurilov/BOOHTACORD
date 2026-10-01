import unittest
from .signature import CERTIFICATE, certificate


class AndroidIdentityTests(unittest.TestCase):
    def test_published_certificate_is_preserved(self):
        text = 'Signer #1 certificate SHA-256 digest: ' + CERTIFICATE
        self.assertEqual(certificate(text, release=True), CERTIFICATE)

    def test_changed_or_missing_signer_cannot_publish(self):
        for text in ('', 'Signer #1 certificate SHA-256 digest: ' + 'a' * 64):
            with self.assertRaises(ValueError): certificate(text, release=True)
