"""User-flow views preserve legacy navigation and honest missing values."""
import json
import unittest
from tools.verify.trace_dashboard.fixture import DashboardFixture


class FlowDashboardTest(DashboardFixture):
    def test_same_dashboard_and_legacy_panels(self):
        self.assertEqual(self.dashboard['uid'], 'boohtacord-traces')
        for key in range(20, 30):
            self.assertIn(key, self.panels)
        self.assertEqual(self.dashboard['refresh'], '30s')
        self.assertEqual(self.dashboard['timezone'], 'browser')

    def test_dependent_filters_keep_all_and_multiselect(self):
        variables = {v['name']: v for v in self.dashboard['templating']['list']}
        for name in ('visit', 'flow', 'media', 'platform', 'client_version', 'operation', 'outcome'):
            self.assertTrue(variables[name]['includeAll'])
            self.assertTrue(variables[name]['multi'])
            self.assertEqual(variables[name]['allValue'], '.*')
        for name in ('visit', 'flow', 'media'):
            self.assertIn('${session:regex}', variables[name]['query']['query'])
        self.assertIn('${visit:regex}', variables['flow']['query']['query'])
        self.assertIn('${flow:regex}', variables['media']['query']['query'])

    def test_terminals_do_not_include_polling_or_infer_success(self):
        query = self.panels[41]['targets'][0]['query']
        self.assertIn('span.app.flow.record = "terminal"', query)
        for field in ('attempt', 'stage', 'outcome', 'reason'):
            self.assertIn('span.app.flow.' + field, query)
        self.assertIn('unknown', self.panels[41]['fieldConfig']['defaults']['noValue'])
        self.assertIn('sampling', self.panels[42]['description'].lower())

    def test_health_is_separate_from_product_history(self):
        self.assertIn('telemetry.export.health', self.panels[49]['targets'][0]['query'])
        self.assertIn('app.export.dropped', self.panels[49]['targets'][0]['query'])
        self.assertIn('unknown', self.panels[49]['description'])
        self.assertIn('boohtacord_telemetry_relay_last_accept_seconds', self.panels[47]['targets'][0]['expr'])
        self.assertEqual(self.panels[46]['datasource']['uid'], 'boohtacord_metrics')

    def test_media_units_and_missing_values_are_explicit(self):
        panel = self.panels[45]
        self.assertEqual(panel['fieldConfig']['defaults']['noValue'], 'unknown')
        query = panel['targets'][0]['query']
        for field in ('source', 'sample_state', 'capture_fps', 'encoded_fps', 'decoded_fps', 'presented_fps'):
            self.assertIn('span.app.media.' + field, query)
        self.assertIn('absent values never mean zero', panel['description'])

    def test_stages_and_workers_do_not_promise_cross_client_latency(self):
        self.assertIn('app.flow.record', self.panels[48]['targets'][0]['query'])
        self.assertIn('clock', self.panels[48]['description'])
        self.assertIn('not acoustic silence', self.panels[44]['description'])
        query = self.panels[44]['targets'][0]['query']
        self.assertIn('span.app.flow.id = nil', query)
        self.assertIn('"${flow:regex}" = ".*"', query)


if __name__ == '__main__':
    unittest.main()
