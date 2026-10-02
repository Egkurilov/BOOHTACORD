"""Keep runtime traffic panels scoped to the selected Grafana interval."""

import json
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[3]


class RuntimeDashboardTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        dashboard = json.loads((ROOT / 'docker/observability/dashboards/runtime.json').read_text(encoding='utf-8'))
        cls.panels = {panel['id']: panel for panel in dashboard['panels']}

    def test_http_totals_and_breakdowns_follow_selected_range(self):
        for panel_id in (2, 3, 7, 8):
            expression = self.panels[panel_id]['targets'][0]['expr']
            self.assertIn('increase(boohtacord_http_server_requests_total', expression)
            self.assertIn('[$__range]', expression)
        self.assertIn('http_response_status_code=~"5.."', self.panels[3]['targets'][0]['expr'])

    def test_rate_and_latency_use_counter_deltas(self):
        traffic = self.panels[5]['targets'][0]['expr']
        latency = self.panels[6]['targets'][0]['expr']
        self.assertIn('rate(boohtacord_http_server_requests_total[$__rate_interval])', traffic)
        self.assertIn('rate(boohtacord_http_server_duration_seconds_bucket{', latency)
        self.assertIn('}[$__range])', latency)
        self.assertIn('http_route!="GET /api/v1/realtime"', latency)
        self.assertTrue(latency.endswith('>= 0'))


if __name__ == '__main__':
    unittest.main()
