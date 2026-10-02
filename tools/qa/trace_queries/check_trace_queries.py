"""Validate dashboard TraceQL against Tempo without printing private identifiers."""
import json
import pathlib
import sys
import time
import urllib.parse
import urllib.request


def panels(items):
    for item in items:
        yield item
        yield from panels(item.get('panels', []))


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: check_trace_queries.py TEMPO_URL DASHBOARD_JSON')
    dashboard = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding='utf-8'))
    now = int(time.time())
    for panel in panels(dashboard['panels']):
        for target in panel.get('targets', []):
            query = target['query'].replace('${user:regex}', '.*').replace('${session:regex}', '.*')
            params = urllib.parse.urlencode({'q': query, 'start': now - 1800, 'end': now, 'limit': 5, 'spss': 5})
            with urllib.request.urlopen(sys.argv[1].rstrip('/') + '/api/search?' + params, timeout=30) as response:
                result = json.load(response)
                print(f"panel={panel['id']} status={response.status} traces={len(result.get('traces', []))}")


if __name__ == '__main__':
    main()
