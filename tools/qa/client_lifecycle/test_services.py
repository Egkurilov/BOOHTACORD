"""Safety boundaries for an autonomous disposable acceptance stack."""
import unittest
from unittest.mock import patch
from .services import local_origin, local_docker, remove_owned


class SafetyTests(unittest.TestCase):
    def test_origin_rejects_remote_and_plaintext(self):
        for value in ('https://v.bootybay.ru', 'http://localhost:4810',
                      'https://localhost.evil:4810', 'https://user@localhost:4810'):
            with self.assertRaises(ValueError):
                local_origin(value)
        self.assertEqual(local_origin('https://localhost:4810'), 'https://localhost:4810')

    def test_docker_rejects_remote_daemon(self):
        with patch.dict('os.environ', {'DOCKER_HOST': 'ssh://production'}):
            with self.assertRaises(ValueError):
                local_docker()

    def test_cleanup_rejects_foreign_container(self):
        with patch('tools.qa.client_lifecycle.services.output', return_value='foreign'), \
                patch('tools.qa.client_lifecycle.services.run') as run:
            with self.assertRaises(ValueError):
                remove_owned('qa-owned', 'owner')
            run.assert_not_called()
