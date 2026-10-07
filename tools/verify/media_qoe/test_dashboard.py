"""Source contracts; real PromQL evaluation lives in promtool fixtures."""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[3]


class MediaDashboardTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dashboard = json.loads((ROOT / 'docker/observability/dashboards/media-qoe.json').read_text())
        cls.mapping = json.loads((ROOT / 'tools/verify/media_qoe/fields.json').read_text())
        cls.panels = cls.dashboard['panels']

    def test_independent_uid_and_private_drilldown(self):
        self.assertEqual(self.dashboard['uid'], 'boohtacord-media-qoe')
        encoded = json.dumps(self.dashboard)
        self.assertIn('/d/boohtacord-traces', encoded)
        for p in self.panels:
            for link in p.get('fieldConfig', {}).get('defaults', {}).get('links', []):
                self.assertNotIn('var-user=', link['url'])
        traces = [t for p in self.panels for t in p.get('targets', []) if 'query' in t]
        self.assertTrue(traces)
        for t in traces:
            self.assertLessEqual(t['limit'], 100)
            self.assertIn('span.user.id != nil', t['query'])
            self.assertIn('span.session.id != nil', t['query'])

    def test_queries_only_use_emitted_metrics_and_keep_population(self):
        allowed = self.mapping['prometheus_metrics']
        for p in self.panels:
            for t in p.get('targets', []):
                expr = t.get('expr', '')
                tokens = re.sub(r'"[^"\\]*(?:\\.[^"\\]*)*"', '""', expr)
                for metric in re.findall(r'\b(?:boohtacord_media|boohtacord_incident|livekit)_\w+', tokens):
                    self.assertIn(metric, allowed, metric)
                self.assertNotIn('or vector(0)', expr)
                if 'histogram_quantile' in expr:
                    self.assertIn('sum by(le,', expr)
                    self.assertIn('rate(', expr)
                    self.assertIn('[5m]', expr)
                    self.assertIn('>= 0', expr)
                if 'boohtacord_media_fps_bucket' in expr:
                    self.assertIn('stage', expr)
                    self.assertIn('age_provenance="known"', expr)

    def test_unknown_unavailable_and_legacy_are_explicit(self):
        text = '\n'.join(p.get('options', {}).get('content', '') + p.get('description', '') for p in self.panels)
        for word in ('legacy', 'unsupported', 'client report', 'SFU', '#159', '#171', 'ACL'):
            self.assertIn(word, text)
        for p in self.panels:
            if p.get('targets'):
                self.assertEqual(p['fieldConfig']['defaults']['noValue'], 'Unknown / no measurement')

    def test_mapping_is_bound_to_exported_production_instruments(self):
        instruments = (ROOT / self.mapping['source_bindings']['client_instruments']).read_text()
        gauges = (ROOT / self.mapping['source_bindings']['receipt_gauges']).read_text()
        histograms = set(re.findall(r'"(\w+)":\s*\{', instruments))
        counters = set(re.findall(r'Int64Counter\("(boohtacord_media_\w+)"', instruments))
        gauge_names = set(re.findall(r'ObservableGauge\("(boohtacord_media_\w+)"', gauges))
        emitted = gauge_names | {name + '_total' for name in counters}
        emitted |= {f'boohtacord_media_{name}_{suffix}' for name in histograms for suffix in ('bucket', 'sum', 'count')}
        for name in self.mapping['prometheus_metrics']:
            if name.startswith('boohtacord_media_'):
                self.assertIn(name, emitted)
        self.assertTrue(self.mapping['unsupported'])
        for p in self.panels:
            if p['title'].startswith('SFU '):
                self.assertIn('up{job="boohtacord-livekit"}', p['targets'][0]['expr'])
                self.assertIn('timestamp(up{', p['targets'][0]['expr'])

    def test_rule_wiring_and_ci_execute_promtool(self):
        for path in ('docker/observability/compose.yaml', 'docker/observability/prometheus.yaml'):
            self.assertIn('media-qoe-alerts.yaml', (ROOT / path).read_text())
        ci = (ROOT / '.github/workflows/ci-contracts.yaml').read_text()
        self.assertIn('tools.verify.media_qoe.test_dashboard', ci)
        self.assertRegex(ci, r'--entrypoint promtool .* test rules')
        self.assertIn('prom/prometheus:v3.11.2', ci)


if __name__ == '__main__':
    unittest.main()
