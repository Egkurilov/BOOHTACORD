"""Protect truthful production resource panels and their operational layout."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]


class ServerResourcesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dashboard = json.loads((ROOT / 'docker/observability/dashboards/runtime.json').read_text(encoding='utf-8'))
        cls.panels = cls.dashboard['panels']

    def test_production_resources_exist_and_use_the_host_datasource(self):
        expressions = '\n'.join(t['expr'] for p in self.panels for t in p.get('targets', []))
        for metric in ('node_cpu_seconds_total', 'node_memory_MemAvailable_bytes',
                       'node_filesystem_avail_bytes', 'node_network_receive_bytes_total',
                       'node_disk_io_time_seconds_total', 'node_netstat_Udp_RcvbufErrors'):
            self.assertIn(metric, expressions)
        for panel in self.panels:
            for target in panel.get('targets', []):
                if 'node_' in target['expr']:
                    self.assertEqual(panel['datasource']['uid'], 'prometheus_main')
                    self.assertIn('instance="176.108.242.211:9100"', target['expr'])
                    self.assertNotIn('or vector(0)', target['expr'])

    def test_overview_has_thresholds_and_neutral_missing_values(self):
        for panel_id in (11, 12, 13):
            panel = next(p for p in self.panels if p['id'] == panel_id)
            defaults = panel['fieldConfig']['defaults']
            self.assertEqual(defaults['unit'], 'percent')
            self.assertEqual(defaults['noValue'], 'Нет данных')
            self.assertEqual([s['color'] for s in defaults['thresholds']['steps']], ['green', 'yellow', 'red'])
            self.assertLess(panel['gridPos']['y'], 12)

    def test_uid_old_panels_and_non_overlapping_layout_are_preserved(self):
        self.assertEqual(self.dashboard['uid'], 'boohtacord-runtime')
        ids = [p['id'] for p in self.panels]
        self.assertTrue(set(range(1, 11)).issubset(ids))
        self.assertEqual(len(ids), len(set(ids)))
        occupied = set()
        for panel in self.panels:
            g = panel['gridPos']
            self.assertLessEqual(g['x'] + g['w'], 24)
            cells = {(x, y) for x in range(g['x'], g['x'] + g['w']) for y in range(g['y'], g['y'] + g['h'])}
            self.assertFalse(cells & occupied, panel['title'])
            occupied |= cells

    def test_network_has_one_physical_interface_and_errors_do_not_fake_zero(self):
        targets = [t['expr'] for p in self.panels for t in p.get('targets', [])]
        network = [q for q in targets if 'node_network_' in q]
        self.assertTrue(network)
        self.assertTrue(all('device="enp3s0"' in q for q in network))
        totals = next(p for p in self.panels if p['id'] == 2)['targets'][0]['expr']
        self.assertNotIn('or vector(0)', totals)

    def test_absolute_free_space_is_neutral_instead_of_default_red_above_80_bytes(self):
        for panel_id in (16, 17):
            defaults = next(p for p in self.panels if p['id'] == panel_id)['fieldConfig']['defaults']
            self.assertEqual(defaults['color'], {'mode': 'fixed', 'fixedColor': 'blue'})
