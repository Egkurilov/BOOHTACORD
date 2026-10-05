"""Inspect real isolated Tempo export without retaining private trace payloads."""
import json
import time
import urllib.parse
import urllib.request


def get(path):
    with urllib.request.urlopen('http://127.0.0.1:4812'+path, timeout=5) as response:
        return json.load(response)


def attributes(span):
    return {item['key']: next(iter(item['value'].values())) for item in span.get('attributes', [])}


def verify(private):
    query = urllib.parse.urlencode({'q': '{ name = "registration.welcome" }'})
    for _ in range(60):
        traces = get('/api/search?'+query).get('traces', [])
        if traces:
            break
        time.sleep(.5)
    else:
        raise AssertionError('No actual welcome trace in disposable Tempo')
    trace = get('/api/traces/'+traces[0]['traceID'])
    groups = trace.get('batches', trace.get('resourceSpans', []))
    spans = [span for group in groups for scope in group.get('scopeSpans', []) for span in scope['spans']]
    children = [span for span in spans if span['name'] == 'registration.welcome']
    assert len(children) == 1, 'Expected one actual welcome child'
    child = children[0]
    roots = [span for span in spans if span['spanId'] == child['parentSpanId']]
    assert len(roots) == 1, 'Welcome must have the actual register parent'
    root = roots[0]
    assert attributes(root)['http.route'] == 'POST /api/v1/auth/register'
    assert root['traceId'] == child['traceId']
    assert attributes(root)['user.id'] == private['accountId']
    details = attributes(child)
    assert details['user.id'] == private['accountId']
    assert details['welcome.outcome'] == 'published'
    assert details['channel.id'] == private['channelId']
    assert details['message.id'] == private['message']['id']
    raw = json.dumps(trace, ensure_ascii=False)
    for secret in (private['password'], private['message']['body'], 'Автономная гильдия'):
        assert secret not in raw, 'Private trace contains prohibited content'
    with urllib.request.urlopen('http://127.0.0.1:4820/metrics', timeout=5) as response:
        metrics = response.read().decode()
    lines = [line for line in metrics.splitlines() if line.startswith((
        'voice_platform_registration_welcome_total{', 'voice_platform_guild_settings_updates_total{'))]
    assert lines and any('outcome="published"' in line for line in lines)
    for line in lines:
        assert line.count('=') == 1 and 'outcome=' in line, 'Unbounded lifecycle metric label'
        for secret in (private['accountId'], private['channelId'], 'qa_member', private['password']):
            assert secret not in line
    return {'status': 'PASS', 'actual_tempo': True, 'register_parent_welcome_child': True,
            'identity_matches_database': True, 'sensitive_content_absent': True, 'bounded_metrics': True}
