import tempfile
import unittest
import zipfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from .inspect import inspect_size


class ApkSizeTests(unittest.TestCase):
    def apk(self, *, compression=zipfile.ZIP_DEFLATED, extra=None):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        path = Path(temporary.name) / 'app.apk'
        entries = {'lib/arm64-v8a/libapp.so': b'app' * 1000,
                   'lib/arm64-v8a/libflutter.so': b'engine' * 2000}
        entries.update(extra or {})
        with zipfile.ZipFile(path, 'w', compression=compression) as archive:
            for name, body in entries.items(): archive.writestr(name, body)
        return path

    def test_compressed_split_release_reports_actual_download_and_native_bytes(self):
        path = self.apk()
        report = inspect_size(path, release=True, architecture='arm64-v8a')
        self.assertEqual(report['apk_bytes'], path.stat().st_size)
        self.assertEqual(report['architectures'], ['arm64-v8a'])
        self.assertEqual(report['native_bytes'], 15000)
        self.assertLess(report['native_compressed_bytes'], report['native_bytes'])

    def test_raw_native_release_libraries_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'compressed'):
            inspect_size(self.apk(compression=zipfile.ZIP_STORED),
                         release=True, architecture='arm64-v8a')

    def test_mixed_or_wrong_release_abi_is_rejected(self):
        for extra, expected in [({'lib/x86_64/libapp.so': b'x'}, 'arm64-v8a'),
                                ({}, 'armeabi-v7a')]:
            with self.subTest(extra=extra, expected=expected), self.assertRaises(ValueError):
                inspect_size(self.apk(extra=extra), release=True, architecture=expected)

    def test_debug_kernel_cannot_be_published_as_release(self):
        path = self.apk(extra={'assets/flutter_assets/kernel_blob.bin': b'debug'})
        with self.assertRaisesRegex(ValueError, 'debug'):
            inspect_size(path, release=True, architecture='arm64-v8a')

    def test_debug_inventory_remains_available(self):
        path = self.apk(compression=zipfile.ZIP_STORED,
                        extra={'assets/flutter_assets/kernel_blob.bin': b'debug'})
        report = inspect_size(path, release=False, architecture='universal')
        self.assertEqual(report['apk_bytes'], path.stat().st_size)

    def test_release_download_budget_is_enforced(self):
        with patch.object(Path, 'stat', return_value=SimpleNamespace(st_size=40000000)):
            with self.assertRaisesRegex(ValueError, 'budget'):
                inspect_size(self.apk(), release=True, architecture='arm64-v8a')

    def test_android_packaging_explicitly_compresses_native_libraries(self):
        build = Path(__file__).resolve().parents[4] / 'clients/flutter/android/app/build.gradle.kts'
        self.assertIn('useLegacyPackaging = true', build.read_text(encoding='utf-8'))
