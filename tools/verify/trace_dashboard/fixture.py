import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]

class DashboardFixture(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dashboard = json.loads((ROOT / 'docker/observability/dashboards/traces.json').read_text(encoding='utf-8'))
        cls.panels = {p['id']: p for p in cls.dashboard['panels']}
