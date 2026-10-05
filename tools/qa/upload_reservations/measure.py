"""Compare actual private metrics with the exact owned attachment filesystem."""
import decimal
import time
import urllib.request
from tools.qa.client_lifecycle.services import output

PREFIX = 'voice_platform_attachment_'
NAMES = ('filesystem_available_bytes', 'filesystem_total_bytes', 'upload_reserved_bytes', 'filesystem_snapshot_success')


def parse_metrics(source):
    values = {}
    for name in NAMES:
        rows = [line.split() for line in source.splitlines() if line.startswith(PREFIX+name+' ')]
        assert len(rows) == 1 and len(rows[0]) == 2, 'Missing or duplicate filesystem metric'
        value = decimal.Decimal(rows[0][1])
        assert value.is_finite() and value >= 0 and value == int(value), 'Invalid filesystem metric'
        values[name] = int(value)
    return values


def sample(stack, build=None):
    with urllib.request.urlopen('http://127.0.0.1:4820/metrics', timeout=5) as response:
        values = parse_metrics(response.read().decode())
    available, total, block = map(int, output('docker', 'exec', stack.keeper, 'stat', '-f', '-c', '%a %b %S', '/attachments').split())
    return dict(at=time.monotonic(), available=available*block, total=total*block,
                metric_available=values[NAMES[0]], metric_total=values[NAMES[1]],
                reserved=values[NAMES[2]], snapshot_success=values[NAMES[3]],
                build_running=build is not None and build.poll() is None)


def await_reserved(stack, expected, samples, build=None):
    deadline = time.monotonic()+10
    while time.monotonic() < deadline:
        snapshot = sample(stack, build)
        samples.append(snapshot)
        if snapshot['reserved'] == expected:
            return
        time.sleep(.1)
    raise AssertionError('Reservation did not reach the expected bounded value')


def validate(samples, limited):
    active = [row for row in samples if row['reserved'] >= 25000000]
    assert len(active) >= 2 and samples[-1]['reserved'] == 0, 'Active reservation and release not proven'
    if not limited:
        assert any(row['build_running'] for row in active), 'No overlapping real build observation'
    for row in samples:
        assert row['snapshot_success'] == 1 and row['metric_total'] == row['total'], 'Wrong attachment filesystem'
        protected = max(2147483648, (row['total']+9)//10)
        required = protected+row['reserved'] if limited else protected*2+25000000+row['reserved']
        assert min(row['available'], row['metric_available']) >= required, 'Observed headroom insufficient'
        assert abs(row['available']-row['metric_available']) <= 1048576, 'Snapshot drift exceeds bounded writes'
