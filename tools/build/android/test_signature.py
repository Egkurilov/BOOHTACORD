import unittest
from .signature import CERTIFICATE, certificate


class AndroidIdentityTests(unittest.TestCase):
    def test_published_certificate_is_preserved(self):
        text = 'Signer #1 certificate SHA-256 digest: ' + CERTIFICATE
        self.assertEqual(certificate(text, release=True), CERTIFICATE)

    def test_changed_or_missing_signer_cannot_publish(self):
        for text in ('', 'Signer #1 certificate SHA-256 digest: ' + 'a' * 64):
            with self.assertRaises(ValueError): certificate(text, release=True)

    def test_ci_v2_signer_format(self):
        self.assertEqual(certificate('V2 Signer: certificate SHA-256 digest: ' + CERTIFICATE,
                                     release=True), CERTIFICATE)

    def test_schemes_must_agree_on_the_same_certificate(self):
        same = '\n'.join(f'V{version} Signer: certificate SHA-256 digest: {CERTIFICATE}'
                         for version in (1, 2, 3))
        self.assertEqual(certificate(same, release=True), CERTIFICATE)
        for changed in (same.replace('V2 Signer: certificate SHA-256 digest: ' + CERTIFICATE,
                                    'V2 Signer: certificate SHA-256 digest: ' + 'a' * 64),
                        same + '\nV2 Signer: certificate SHA-256 digest: ' + CERTIFICATE):
            with self.assertRaises(ValueError): certificate(changed, release=False)
