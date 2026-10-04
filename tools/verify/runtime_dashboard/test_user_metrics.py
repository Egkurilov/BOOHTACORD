"""Audience statistics must remain aggregate, fresh and honest about missing history."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]


class UserMetricsTest(unittest.TestCase):
    def test_user_panels_use_fresh_successful_aggregate_collection(self):
        dashboard = json.loads((ROOT / 'docker/observability/dashboards/runtime.json').read_text(encoding='utf-8'))
        panels = {p['id']: p for p in dashboard['panels']}
        self.assertIn(210, panels, 'registered user history is required')
        self.assertEqual(panels[210]['type'], 'timeseries')
        for panel_id in range(202, 212):
            panel = panels[panel_id]
            self.assertEqual(panel['datasource']['uid'], 'boohtacord_metrics')
            for target in panel['targets']:
                self.assertIn('boohtacord_users_collection_success', target['expr'])
                self.assertIn('boohtacord_users_collected_at_seconds', target['expr'])
                self.assertNotIn('or vector(0)', target['expr'])
                self.assertNotIn('user_id', target['expr'])
        for panel_id in (205, 208, 209):
            self.assertIn('boohtacord_users_previous_day_complete', panels[panel_id]['targets'][0]['expr'])
        self.assertIn('> 0', panels[205]['targets'][0]['expr'], 'zero baseline must not produce infinite growth')
        self.assertNotIn('min', panels[209]['fieldConfig']['defaults'], 'a daily change may be negative')
