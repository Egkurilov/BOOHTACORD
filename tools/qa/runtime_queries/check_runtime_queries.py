"""Execute each dashboard PromQL against its configured read-only Prometheus API."""
import argparse
import json
import math
from pathlib import Path
import time
import urllib.parse
import urllib.request


def check(dashboard, sources):
    now = int(time.time())
    results = []
    for panel in dashboard['panels']:
        for target in panel.get('targets', []):
            source = sources[panel['datasource']['uid']]
            query = target['expr'].replace('$__rate_interval', '5m').replace('$__range', '6h')
            for mode in (['query'] if target.get('instant') else ['query', 'query_range']):
                params = {'query': query}
                params.update({'time': now} if mode == 'query' else {'start': now - 3600, 'end': now, 'step': 60})
                url = source.rstrip('/') + '/api/v1/' + mode + '?' + urllib.parse.urlencode(params)
                with urllib.request.urlopen(url, timeout=30) as response:
                    data = json.load(response)
                if data['status'] != 'success':
                    raise ValueError(f"panel {panel['id']} query failed: {data.get('error')}")
                series = data['data']['result']
                values = [pair[1] for item in series for pair in item.get('values', [item.get('value')]) if pair]
                if any(not math.isfinite(float(value)) for value in values):
                    raise ValueError(f"panel {panel['id']} has non-finite samples")
                results.append({'panel': panel['id'], 'target': target['refId'], 'mode': mode,
                                'series': len(series), 'samples': len(values),
                                'values': values if mode == 'query' and panel['type'] == 'stat' else None})
    return {'checked_at_unix_seconds': now, 'queries': len(results),
            'empty_results': sum(not r['series'] for r in results), 'results': results}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('dashboard', type=Path)
    parser.add_argument('--host-prometheus', required=True)
    parser.add_argument('--app-prometheus', required=True)
    args = parser.parse_args()
    dashboard = json.loads(args.dashboard.read_text(encoding='utf-8'))
    print(json.dumps(check(dashboard, {'prometheus_main': args.host_prometheus,
                                     'boohtacord_metrics': args.app_prometheus}), indent=2))


if __name__ == '__main__':
    main()
