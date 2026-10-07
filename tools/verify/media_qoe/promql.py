"""Materialize actual dashboard expressions as recording rules for promtool."""
import json
from pathlib import Path
import re
import sys

import yaml

ROOT = Path(__file__).resolve().parents[3]


def main():
    output = Path(sys.argv[1])
    output.mkdir(parents=True, exist_ok=True)
    dashboard = json.loads((ROOT / 'docker/observability/dashboards/media-qoe.json').read_text())
    rules = []
    for panel in dashboard['panels']:
        for target in panel.get('targets', []):
            if 'expr' not in target:
                continue
            expr = re.sub(r'\$\{(?:platform|direction):regex\}', '.*', target['expr'])
            rules.append({'record': f'media_dashboard_panel_{panel["id"]}', 'expr': expr})
    if not rules:
        raise RuntimeError('no media dashboard PromQL expressions')
    (output / 'dashboard-rules.yaml').write_text(yaml.safe_dump({
        'groups': [{'name': 'media-dashboard-source-check', 'rules': rules}]}, sort_keys=False, width=2000))
    tests = [
        {'name': 'empty_source_is_unknown', 'interval': '1m', 'input_series': [],
         'promql_expr_test': [{'expr': r['record'], 'eval_time': '10m', 'exp_samples': []} for r in rules]},
    ]
    # Actual FPS histogram (30 FPS) and stale/legacy guards: no rendered green zero.
    labels = 'platform="desktop_web",direction="sender",source="client_report"'
    buckets = []
    for bound in ('0', '1', '5', '15', '24', '30', '45', '55', '60', '90', '120', '240', '+Inf'):
        values = '0+0x15' if bound != '+Inf' and float(bound) < 30 else '0+30x15'
        buckets.append({'series': 'boohtacord_media_fps_bucket{'+labels+',state="playing",stage="encoded",age_provenance="known",le="'+bound+'"}', 'values': values})
    common = buckets + [
        {'series': 'boohtacord_media_report_received_seconds{'+labels+'}', 'values': '0+60x15'},
        {'series': 'boohtacord_media_sample_age_known{'+labels+'}', 'values': '1+0x15'},
        {'series': 'boohtacord_media_sample_age_at_receipt_seconds{'+labels+'}', 'values': '1+0x15'},
    ]
    for name, age in [('current', '1+0x15'), ('stale', '70+0x15')]:
        tests.append({'name': name+'_actual_stage', 'interval': '1m',
                      'input_series': common + [{'series': 'boohtacord_media_sample_age_seconds{'+labels+'}', 'values': age}],
                      'promql_expr_test': [{'expr': 'media_dashboard_panel_2', 'eval_time': '10m',
                       'exp_samples': [] if name == 'stale' else [{'labels': '{__name__="media_dashboard_panel_2",age_provenance="known",direction="sender",platform="desktop_web",stage="encoded",state="playing"}', 'value': 24.3}]}]})
    tests.append({'name': 'legacy_is_unknown_current_fps', 'interval': '1m',
                  'input_series': [{'series': b['series'].replace('age_provenance="known"', 'age_provenance="legacy"'), 'values': b['values']} for b in buckets],
                  'promql_expr_test': [{'expr': 'media_dashboard_panel_2', 'eval_time': '10m', 'exp_samples': []}]})
    (output / 'dashboard.test.yaml').write_text(yaml.safe_dump({
        'rule_files': ['dashboard-rules.yaml'], 'evaluation_interval': '1m', 'tests': tests}, sort_keys=False, width=2000))


if __name__ == '__main__':
    main()
