"""Contracts for navigable, bounded and identity-safe trace views."""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class TracesDashboardTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dashboard = json.loads((ROOT / 'docker/observability/dashboards/traces.json').read_text(encoding='utf-8'))
        cls.panels = {p['id']: p for p in cls.dashboard['panels']}

    def test_identity_filters_are_tempo_labels_and_default_to_all(self):
        variables = {v['name']: v for v in self.dashboard['templating']['list']}
        for name in ('user', 'session'):
            variable = variables[name]
            self.assertEqual(variable['query']['label'], f'{name}.id')
            self.assertEqual(variable['query']['type'], 1)
            self.assertEqual(variable['current']['value'], '$__all')
            self.assertTrue(variable['includeAll'])

    def test_session_summary_groups_spans_and_links_to_filtered_timeline(self):
        panel = self.panels[21]
        target = panel['targets'][0]
        self.assertEqual(target['tableType'], 'spans')
        self.assertEqual(target['limit'], 500)
        for identity in ('user', 'session'):
            self.assertIn('span.' + identity + '.id', target['query'])
            self.assertIn('${' + identity + ':regex}', target['query'])
        group = next(t for t in panel['transformations'] if t['id'] == 'groupBy')
        self.assertEqual(group['options']['fields']['span.session.id']['operation'], 'groupby')
        encoded = json.dumps(panel, ensure_ascii=False)
        self.assertIn('var-session=${__value.raw}', encoded)
        self.assertIn('выборк', panel['description'])

    def test_clients_are_linked_through_verified_server_spans(self):
        query = self.panels[22]['targets'][0]['query']
        for platform in ('web', 'android', 'ios', 'windows', 'macos'):
            self.assertIn(platform, query)
        self.assertIn('} &&', query)
        self.assertIn('span.user.id', query)

    def test_websocket_lifetime_is_not_a_slow_http_request(self):
        query = self.panels[24]['targets'][0]['query']
        self.assertIn('span.http.route != "GET /api/v1/realtime"', query)
        self.assertIn('duration > 1s', query)

    def test_background_and_old_traces_remain_available_but_collapsed(self):
        row = self.panels[29]
        self.assertTrue(row['collapsed'])
        self.assertGreaterEqual(len(row['panels']), 2)
        self.assertTrue(any('span.user.id = nil' in p['targets'][0]['query'] for p in row['panels']))


if __name__ == '__main__':
    unittest.main()
