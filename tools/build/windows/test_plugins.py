import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from .plugins import configured_plugins


class ConfiguredPluginsTests(unittest.TestCase):
    def test_restores_generated_input_after_build_success_and_failure(self):
        for fail in (False, True):
            with self.subTest(fail=fail), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                cmake = root / 'windows/flutter/generated_plugins.cmake'
                cmake.parent.mkdir(parents=True)
                original = b'canonical generated input\r\n'
                cmake.write_bytes(original)
                with patch('tools.build.windows.plugins.configure',
                           side_effect=lambda _: cmake.write_bytes(b'build host paths')):
                    try:
                        with configured_plugins(root):
                            self.assertEqual(cmake.read_bytes(), b'build host paths')
                            if fail: raise RuntimeError('build failed')
                    except RuntimeError:
                        self.assertTrue(fail)
                self.assertEqual(cmake.read_bytes(), original)
