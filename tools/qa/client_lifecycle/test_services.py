"""Safety boundaries for an autonomous disposable acceptance stack."""
import unittest
import socket
from unittest.mock import patch
from .services import local_origin, local_docker, remove_owned, ports_available


class SafetyTests(unittest.TestCase):
    def test_port_probe_reuses_closed_connections_before_binding(self):
        with patch('tools.qa.client_lifecycle.services.socket.socket') as factory:
            listener = factory.return_value.__enter__.return_value
            ports_available((4810,))
            self.assertEqual(listener.mock_calls[:2], [
                unittest.mock.call.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1),
                unittest.mock.call.bind(('127.0.0.1', 4810))])

    def test_port_probe_rejects_active_listener(self):
        with socket.socket() as server:
            server.bind(('127.0.0.1', 0))
            server.listen()
            with self.assertRaises(OSError):
                ports_available((server.getsockname()[1],))

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

    def test_cleanup_removes_only_a_labelled_owned_image(self):
        with patch('tools.qa.client_lifecycle.services.output', return_value='owner'), \
                patch('tools.qa.client_lifecycle.services.run') as run:
            remove_owned('qa-api', 'owner', 'image')
            self.assertEqual(run.call_args.args, ('docker', 'image', 'rm', 'qa-api'))

    def test_cleanup_rejects_an_unsupported_resource_kind(self):
        with patch('tools.qa.client_lifecycle.services.output') as output, \
                patch('tools.qa.client_lifecycle.services.run') as run:
            with self.assertRaises(ValueError):
                remove_owned('qa-data', 'owner', 'volume')
            output.assert_not_called()
            run.assert_not_called()
