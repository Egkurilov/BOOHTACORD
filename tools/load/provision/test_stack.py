import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from .stack import Stack


class FreshFixtureTests(unittest.TestCase):
    def test_no_inherited_production_telemetry_or_external_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            with patch.dict(os.environ, {'OTEL_EXPORTER_OTLP_ENDPOINT': 'https://production.invalid',
                                        'OTEL_INGEST_AUTH': 'private', 'QA_BIN_DIR': ''}):
                stack = Stack(work, work)
                self.assertFalse(any(name.startswith('OTEL_') for name in stack.environment))
            with patch.dict(os.environ, {'QA_BIN_DIR': 'external-binary'}):
                with self.assertRaises(ValueError):
                    Stack(work, work)

    def test_api_trusts_only_exact_docker_proxy_gateways(self):
        stack = Stack.__new__(Stack)
        stack.owner = 'qa-load-fixture'
        stack.environment = {'TRUSTED_PROXY_CIDRS': '127.0.0.1/32'}
        networks = {
            'bridge': [{'IPAM': {'Config': [{'Gateway': '172.17.0.1'}]}}],
            stack.owner: [{'IPAM': {'Config': [{'Gateway': '172.30.0.1'}]}}],
        }
        with patch('tools.load.provision.stack.output', side_effect=lambda *_args: json.dumps(networks[_args[-1]])), \
                patch('tools.load.provision.stack.ExistingStack.start_api') as start_api:
            stack.start_api()

        self.assertEqual(stack.environment['TRUSTED_PROXY_CIDRS'],
                         '127.0.0.1/32,172.17.0.1/32,172.30.0.1/32')
        start_api.assert_called_once_with()


if __name__ == '__main__':
    unittest.main()
