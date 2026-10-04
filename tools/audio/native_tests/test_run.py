import unittest
from unittest.mock import patch
from .run import main


class NativeAudioGateTests(unittest.TestCase):
    def test_builds_and_runs_registered_tests_in_release_with_empty_suite_guard(self):
        with patch('tools.audio.native_tests.run.run') as command:
            main()
        calls = [call.args for call in command.call_args_list]
        self.assertIn('-DBOOHTA_RNNOISE_TESTS=ON', calls[0])
        self.assertEqual(calls[1][0:2], ('cmake', '--build'))
        self.assertIn('--config', calls[1])
        self.assertIn('Release', calls[1])
        self.assertIn('--no-tests=error', calls[2])
        self.assertIn('--output-on-failure', calls[2])
