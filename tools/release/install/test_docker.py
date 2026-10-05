import json
import unittest
from pathlib import Path
from unittest.mock import patch
from .docker import deploy


class WriterPreflightTests(unittest.TestCase):
    def test_second_running_writer_blocks_rollout_before_mutation(self):
        with patch('tools.release.install.docker.docker', side_effect=[
                json.dumps({'services': {'api': {}}}), 'one\ntwo']), \
                patch('tools.release.install.docker.subprocess.run') as rollout:
            with self.assertRaises(ValueError):
                deploy(Path('/retained'), {'components': {}})
            rollout.assert_not_called()

    def test_supported_writer_reaches_existing_guarded_rollout(self):
        with patch('tools.release.install.docker.docker', side_effect=[
                json.dumps({'services': {'api': {'deploy': {'replicas': 1}}}}), 'one']), \
                patch('tools.release.install.docker.subprocess.run') as rollout:
            deploy(Path('/retained'), {'components': {'api': {'index_digest': 'sha256:'+'a'*64}}})
            rollout.assert_called_once()
            self.assertEqual(rollout.call_args.kwargs['env']['API_IMAGE'], 'voice-platform-api@sha256:'+'a'*64)
