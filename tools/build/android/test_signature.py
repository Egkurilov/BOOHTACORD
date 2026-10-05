import unittest
from pathlib import Path
from unittest.mock import patch
from .signature import APPLICATION, CERTIFICATE, certificate, inspect


class AndroidIdentityTests(unittest.TestCase):
    def inspect_code(self, code, native_code=''):
        badging = (f"package: name='{APPLICATION}' versionCode='{code}' versionName='1.0.30'\n"
                   + native_code)
        with patch('tools.build.android.signature.tools_directory', return_value=Path('35.0.0')), \
                patch('tools.build.android.signature.output', side_effect=[
                    'Signer #1 certificate SHA-256 digest: ' + CERTIFICATE, badging]):
            return inspect(Path('app-release.apk'), release=True, version='1.0.30+44')

    def test_actual_split_apk_codes_match_their_abi(self):
        for abi, code in [('armeabi-v7a', 1044), ('arm64-v8a', 2044), ('x86_64', 4044)]:
            self.assertEqual(self.inspect_code(code, f"native-code: '{abi}'")['version_code'], code)

    def test_universal_apk_has_base_build_number(self):
        self.assertEqual(self.inspect_code(44,
            "native-code: 'armeabi-v7a' 'arm64-v8a' 'x86_64'")['version_code'], 44)

    def test_wrong_abi_or_base_cannot_publish(self):
        for code, native in [(1044, "native-code: 'arm64-v8a'"),
                             (2043, "native-code: 'arm64-v8a'"),
                             (2044, ''), (44, "native-code: 'arm64-v8a'"),
                             (3044, "native-code: 'x86'")]:
            with self.subTest(code=code, native=native), self.assertRaises(ValueError):
                self.inspect_code(code, native)

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
