"""Real TLS/Origin/cookie requests and manually paced multipart uploads."""
import http.client
import json
import ssl
from http.cookies import SimpleCookie
from tools.qa.client_lifecycle.services import local_origin

ORIGIN = local_origin('https://localhost:4810')
DATA = b'bounded synthetic attachment\n'*20000
START = b'--qa-boundary\r\nContent-Disposition: form-data; name="file"; filename="fixture.txt"\r\nContent-Type: text/plain\r\n\r\n'
END = b'\r\n--qa-boundary--\r\n'


def connection():
    return http.client.HTTPSConnection('localhost', 4810, context=ssl._create_unverified_context(), timeout=10)


class Client:
    def __init__(self, password, login='qa_admin'):
        self.cookie = ''
        status, _, headers = self.request('/auth/login', 'POST', {'login': login, 'password': password})
        assert status == 204, 'Synthetic fixture login failed'
        cookie = SimpleCookie(headers['Set-Cookie'])
        self.cookie = 'vp_session='+cookie['vp_session'].value

    def create_peer(self, password):
        login = 'qa_upload_peer'
        status, _, _ = self.request('/auth/register', 'POST', {'login': login, 'password': password})
        assert status == 201, f'Synthetic independent uploader registration returned {status}'
        return Client(password, login)

    def request(self, path, method='GET', body=None):
        client = connection()
        try:
            client.request(method, '/api/v1'+path, body=None if body is None else json.dumps(body),
                           headers={'Origin': ORIGIN, 'Cookie': self.cookie, 'Content-Type': 'application/json'})
            response = client.getresponse()
            raw = response.read()
            return response.status, json.loads(raw) if raw else None, dict(response.getheaders())
        finally:
            client.close()

    def create_channel(self):
        status, category, _ = self.request('/admin/categories', 'POST', {'name': 'UploadFixture'})
        assert status == 201
        status, channel, _ = self.request('/admin/categories/'+category['id']+'/channels', 'POST', {'name': 'UploadFixture', 'kind': 'TEXT'})
        assert status == 201
        return channel['id']

    def upload(self, channel):
        client = connection()
        client.putrequest('POST', '/api/v1/channels/'+channel+'/attachments')
        for name, value in {'Origin': ORIGIN, 'Cookie': self.cookie,
                            'Content-Type': 'multipart/form-data; boundary=qa-boundary',
                            'Content-Length': str(len(START)+len(DATA)+len(END))}.items():
            client.putheader(name, value)
        client.endheaders()
        client.send(START+DATA[:8192])
        return client


def finish(client):
    try:
        client.send(DATA[8192:]+END)
        response = client.getresponse()
        response.read()
        return response.status
    finally:
        client.close()
