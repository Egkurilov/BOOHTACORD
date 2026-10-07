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


if __name__ == '__main__':
    unittest.main()
