import copy
import unittest
from pathlib import Path
import yaml
from tools.verify.workflows.delivery import check


class DeliveryWorkflowTests(unittest.TestCase):
    def setUp(self):
        root = Path(__file__).resolve().parents[3]
        self.workflows = {path.name: yaml.load(path.read_text(encoding='utf-8'), Loader=yaml.BaseLoader)
                          for path in (root / '.github/workflows').glob('*.yaml')}

    def test_current_delivery_graph(self):
        check(self.workflows)

    def test_installer_cannot_cancel_another_writer(self):
        broken = copy.deepcopy(self.workflows)
        broken['deploy-production.yaml']['concurrency']['cancel-in-progress'] = 'true'
        with self.assertRaises(ValueError): check(broken)

    def test_builder_requires_all_source_bound_gates(self):
        broken = copy.deepcopy(self.workflows)
        broken['build-server.yaml']['jobs']['bundle']['needs'] = ['backend', 'web']
        with self.assertRaises(ValueError): check(broken)

    def test_untrusted_workflow_completion_cannot_deploy(self):
        broken = copy.deepcopy(self.workflows)
        broken['deploy-production.yaml']['jobs']['install']['if'] = 'true'
        with self.assertRaises(ValueError): check(broken)
