import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from tools.audio.asset_build import build_assets, compiler_command
from tools.build.server.inputs import SOURCE_PATHS


class AudioAssetBuildTests(unittest.TestCase):
    def test_release_archive_contains_only_native_core_subtree(self):
        self.assertIn('clients/flutter/packages/flutter_webrtc/common/rnnoise/upstream', SOURCE_PATHS)
        self.assertNotIn('clients/flutter', SOURCE_PATHS)

    def test_compiler_is_digest_pinned_and_source_mounted(self):
        command = compiler_command(Path('/source'))
        self.assertIn('emscripten/emsdk:4.0.20@sha256:460fff8f8ac87e11b16447fbd66538a686eafa0e4fb977aa0989ed19fe2079f7', command)
        self.assertIn('/source:/src', command)
        self.assertEqual(command[-2:], ['python3', 'tools/audio/build_rnnoise.py'])

    @unittest.skipUnless(os.name == 'posix', 'POSIX numeric ownership gate')
    def test_compiler_does_not_leave_root_owned_release_assets(self):
        with patch('tools.audio.asset_build.os.getuid', return_value=1001), patch('tools.audio.asset_build.os.getgid', return_value=1002):
            command = compiler_command(Path('/source'))
            self.assertIn('--user', command)
            self.assertEqual(command[command.index('--user') + 1], '1001:1002')
            self.assertIn('EM_CACHE=/tmp/rnnoise-emscripten-cache', command)

    def test_never_reuses_unverified_generated_assets(self):
        with tempfile.TemporaryDirectory() as directory, patch('tools.audio.asset_build.subprocess.run') as run:
            root = Path(directory)
            build_assets(root)
            build_assets(root)
            self.assertEqual(run.call_count, 2)
            self.assertTrue(run.call_args.kwargs['check'])
