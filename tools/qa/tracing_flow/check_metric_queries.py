"""Execute dashboard PromQL against an isolated private Prometheus only."""
import ipaddress
import json
import pathlib
import sys
import urllib.parse
import urllib.request


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: check_metric_queries.py PRIVATE_PROMETHEUS DASHBOARD_JSON')
    base = urllib.parse.urlsplit(sys.argv[1])
    host = base.hostname
    if (base.scheme != 'http' or base.username or not host or
            (host != 'localhost' and not ipaddress.ip_address(host).is_private)):
        raise SystemExit('isolated private HTTP QA endpoint required')
    dashboard = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding='utf-8'))
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    count = 0
    for panel in dashboard['panels']:
        for target in panel.get('targets', []):
            query = target.get('expr')
            if not query:
                continue
            url = sys.argv[1].rstrip('/') + '/api/v1/query?' + urllib.parse.urlencode({'query': query})
            with opener.open(url, timeout=10) as response:
                result = json.load(response)
            if result.get('status') != 'success':
                raise SystemExit(f"panel={panel['id']} query rejected")
            print(f"panel={panel['id']} status=success series={len(result['data']['result'])}")
            count += 1
    if count == 0:
        raise SystemExit('no PromQL expressions found')


if __name__ == '__main__':
    main()
