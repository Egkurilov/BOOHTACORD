import copy
import unittest
from pathlib import Path
import yaml
from .check import validate


class WriterTopologyTests(unittest.TestCase):
    def setUp(self):
        self.compose = yaml.safe_load((Path(__file__).resolve().parents[3]/'deploy/compose.yaml').read_text())

    def test_supported_topology(self):
        validate(self.compose)

    def test_two_replicas_rejected(self):
        value = copy.deepcopy(self.compose)
        value['services']['api']['deploy']['replicas'] = 2
        with self.assertRaises(ValueError):
            validate(value)

    def test_start_first_rollout_or_rollback_rejected(self):
        for action in ('update_config', 'rollback_config'):
            value = copy.deepcopy(self.compose)
            value['services']['api']['deploy'][action]['order'] = 'start-first'
            with self.assertRaises(ValueError):
                validate(value)
