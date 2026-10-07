"""Render aggregate load evidence with honest per-series units and window sizes."""
import csv
import html
import json


def render(destination, report):
    driver = report.get('driver', {})
    rows = driver.get('Routes', {})
    with (destination/'routes.csv').open('w', newline='') as stream:
        writer = csv.writer(stream)
        writer.writerow(('route', 'count', 'errors', 'p50_ms', 'p95_ms', 'p99_ms'))
        for name, row in sorted(rows.items()):
            writer.writerow((name, row['Count'], row['Errors'], row['P50MS'], row['P95MS'], row['P99MS']))
    panels = []
    for field, label, divisor in (('CPUPercent', 'API CPU % of host', 1),
                                  ('RSSBytes', 'API RSS MiB', 1 << 20),
                                  ('FreeBytes', 'Attachment free MiB', 1 << 20)):
        values = [row[field]/divisor for row in driver.get('Resources') or []]
        if not values:
            panels.append('<p>'+label+': NOT_RUN</p>')
            continue
        maximum = max(values) or 1
        points = ' '.join(f'{i*580/max(1,len(values)-1):.2f},{120-value/maximum*110:.2f}'
                          for i, value in enumerate(values))
        panels.append(f'<h2>{label}</h2><p>0–{maximum:.2f}; one sample per guard tick</p>'
                      f'<svg viewBox="0 0 600 130" role="img" aria-label="{label}">'
                      f'<polyline fill="none" stroke="#2563eb" stroke-width="2" points="{points}"/></svg>')
    table = '<table><tr><th>Route</th><th>Count</th><th>Errors</th><th>p95 ms</th></tr>'
    for name, row in sorted(rows.items()):
        table += f'<tr><td>{html.escape(name)}</td><td>{row["Count"]}</td><td>{row["Errors"]}</td><td>{row["P95MS"]:.2f}</td></tr>'
    table += '</table>'
    page = '<!doctype html><html lang="en"><meta charset="utf-8"><title>Backend load evidence</title>'
    page += '<style>body{font:16px system-ui;margin:32px;max-width:960px}svg{width:100%;max-width:600px}td,th{text-align:left;padding:6px 20px}</style>'
    page += '<h1>Backend load evidence</h1><p>Protocol workload; physical capacity/media NOT_RUN. Quantiles: last 6000 observations per route.</p>'
    page += '<pre>'+html.escape(json.dumps(driver.get('Criteria', {}), indent=2))+'</pre>'
    (destination/'report.html').write_text(page+table+''.join(panels)+'</html>')
