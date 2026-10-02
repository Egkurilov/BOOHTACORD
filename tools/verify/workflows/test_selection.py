import copy
import unittest
from pathlib import Path
import yaml
from .selection import check


class WorkflowSelectionTests(unittest.TestCase):
    def setUp(self):
        root = Path(__file__).resolve().parents[3]
        self.document = yaml.load((root / '.github/workflows/ci.yaml').read_text(encoding='utf-8'), Loader=yaml.BaseLoader)

    def test_current_dependency_graph(self):
        check(self.document)

    def test_display_and_job_names_do_not_define_policy(self):
        jobs = self.document['jobs']
        jobs['arbitrary-native-build-name'] = jobs.pop('windows')
        check(self.document)

    def test_missing_dependencies_or_wrong_component_fail(self):
        for changed in ({'needs': []}, {'if': "needs.changes.outputs.web == 'true'"}):
            invalid = copy.deepcopy(self.document)
            invalid['jobs']['windows'].update(changed)
            with self.assertRaises(ValueError):
                check(invalid)

    def test_contracts_cannot_be_hidden_by_path_selection(self):
        self.document['jobs']['contracts']['if'] = 'false'
        with self.assertRaises(ValueError):
            check(self.document)
