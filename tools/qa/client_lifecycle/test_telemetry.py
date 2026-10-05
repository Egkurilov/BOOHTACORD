"""Reject false-positive correlation and privacy claims from the export verifier."""
import io
import unittest
from unittest.mock import patch
from .telemetry import verify


def fixture():
    def attrs(values):
        return [{'key': key, 'value': {'stringValue': value}} for key, value in values.items()]
    root = {'name': 'POST /api/v1/auth/register', 'spanId': 'root', 'traceId': 'trace',
            'attributes': attrs({'http.route': 'POST /api/v1/auth/register', 'user.id': 'account'})}
    child = {'name': 'registration.welcome', 'spanId': 'child', 'traceId': 'trace', 'parentSpanId': 'root',
             'attributes': attrs({'user.id': 'account', 'welcome.outcome': 'published',
                                  'channel.id': 'channel', 'message.id': 'message'})}
    trace = {'batches': [{'scopeSpans': [{'spans': [root, child]}]}]}
    private = {'accountId': 'account', 'channelId': 'channel', 'password': 'private-password',
               'message': {'id': 'message', 'body': 'private-welcome-body'}}
    return trace, private, root, child


class TelemetryTests(unittest.TestCase):
    def check(self, trace, private, metric='voice_platform_registration_welcome_total{outcome="published"} 1'):
        with patch('tools.qa.client_lifecycle.telemetry.get', side_effect=[{'traces': [{'traceID': 'trace'}]}, trace]), \
                patch('urllib.request.urlopen', return_value=io.BytesIO(metric.encode())):
            return verify(private)

    def test_actual_shape_matches_correlation(self):
        trace, private, _, _ = fixture()
        self.assertEqual(self.check(trace, private)['status'], 'PASS')

    def test_parent_and_trace_mismatch_are_not_accepted(self):
        for key in ('parentSpanId', 'traceId'):
            trace, private, _, child = fixture()
            child[key] = 'foreign'
            with self.assertRaises(AssertionError):
                self.check(trace, private)

    def test_password_or_body_leak_is_rejected(self):
        for key in ('password', 'body'):
            trace, private, root, _ = fixture()
            root['name'] = private['password'] if key == 'password' else private['message']['body']
            with self.assertRaises(AssertionError):
                self.check(trace, private)

    def test_identity_label_is_rejected(self):
        trace, private, _, _ = fixture()
        with self.assertRaises(AssertionError):
            self.check(trace, private, 'voice_platform_registration_welcome_total{outcome="published",user="account"} 1')
