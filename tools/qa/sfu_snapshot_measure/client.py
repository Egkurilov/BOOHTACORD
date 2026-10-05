"""Private local-only authenticated requests; credentials never enter reports."""
import http.cookiejar
import json
import ssl
import urllib.request

ORIGIN = 'https://localhost:4810'


class Client:
    def __init__(self, password):
        jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar),
            urllib.request.HTTPSHandler(context=ssl._create_unverified_context()))
        self.request('/auth/login', 'POST', {'login': 'qa_admin', 'password': password})

    def request(self, path, method='GET', body=None):
        assert path.startswith('/') and not path.startswith('//')
        request = urllib.request.Request(ORIGIN+'/api/v1'+path, method=method,
            data=None if body is None else json.dumps(body).encode(),
            headers={'Origin': ORIGIN, 'Content-Type': 'application/json'})
        with self.opener.open(request, timeout=15) as response:
            if path == '/voice/participants':
                assert response.headers['Cache-Control'] == 'no-store'
            return json.load(response) if response.status != 204 else None

    def calls(self):
        with urllib.request.urlopen('http://127.0.0.1:4820/metrics', timeout=15) as response:
            text = response.read().decode()
        lines = [line for line in text.splitlines()
                 if line.startswith('voice_platform_sfu_room_service_calls_total{')]
        assert not any('outcome="failure"' in line and float(line.split()[-1]) for line in lines)
        return sum(float(line.split()[-1]) for line in lines)
