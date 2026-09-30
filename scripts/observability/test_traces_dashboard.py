"""Contracts for navigable, bounded and identity-safe trace views."""
import json
import pathlib
import re
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
            self.assertEqual(variable['query']['label'], 'user.label' if name == 'user' else 'session.id')
            self.assertEqual(variable['query']['type'], 1)
            self.assertEqual(variable['current']['value'], '$__all')
            self.assertTrue(variable['includeAll'])

    def test_friendly_filter_retains_uuid_value_and_stable_grouping(self):
        variable = self.dashboard['templating']['list'][0]
        pattern = variable['regex'].strip('/').replace('(?<', '(?P<')
        account = '03ef6b06-497a-49aa-b70c-7cc031810f83'
        for name in ('Аня [QA]', 'Новое имя', 'Name · with delimiter', 'Name\nQA'):
            label = name + ' · ' + account
            match = re.fullmatch(pattern, label)
            self.assertEqual(match['text'], label)
            self.assertEqual(match['value'], account)
        for panel_id in (21, 33):
            panel = self.panels[panel_id]
            self.assertIn('span.user.name', panel['targets'][0]['query'])
            group = next(t for t in panel['transformations'] if t['id'] == 'groupBy')
            self.assertEqual(group['options']['fields']['user.name']['operation'], 'aggregate')
            self.assertEqual(group['options']['fields']['user.id']['operation'], 'groupby')

    def test_session_summary_groups_spans_and_links_to_filtered_timeline(self):
        panel = self.panels[21]
        target = panel['targets'][0]
        self.assertEqual(target['tableType'], 'spans')
        self.assertEqual(target['limit'], 500)
        for identity in ('user', 'session'):
            self.assertIn('span.' + identity + '.id', target['query'])
            self.assertIn('${' + identity + ':regex}', target['query'])
        group = next(t for t in panel['transformations'] if t['id'] == 'groupBy')
        # Tempo 2.10 returns selected attribute keys without their TraceQL scope.
        self.assertEqual(group['options']['fields']['session.id']['operation'], 'groupby')
        self.assertEqual(group['options']['fields']['user.id']['operation'], 'groupby')
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

    def test_media_samples_keep_identity_units_and_missing_values(self):
        panel = self.panels[33]
        query = panel['targets'][0]['query']
        self.assertIn('name = "media.sample"', query)
        for field in ('user.id', 'session.id', 'media.rtt_ms', 'media.bitrate_kbps', 'media.encoded_fps',
                      'media.decoded_fps', 'media.packet_loss_percent', 'media.packet_loss_window_ms',
                      'media.target_resolution', 'media.target_fps', 'media.frame_width', 'media.frame_height'):
            self.assertIn('span.' + field, query)
        for identity in ('user', 'session'):
            self.assertIn('${' + identity + ':regex}', query)
        group = next(t for t in panel['transformations'] if t['id'] == 'groupBy')
        self.assertEqual(group['options']['fields']['media.rtt_ms']['aggregations'], ['last'])
        units = {o['matcher']['options']: next((p['value'] for p in o['properties'] if p['id'] == 'unit'), None)
                 for o in panel['fieldConfig']['overrides']}
        self.assertEqual(units['media.packet_loss_percent (last)'], 'percent')
        self.assertEqual(units['media.rtt_ms (last)'], 'ms')


if __name__ == '__main__':
    unittest.main()
