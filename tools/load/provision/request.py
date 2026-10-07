"""Local fixture provisioning over the actual secure-cookie API."""
import http.cookiejar
import json
import ssl
import urllib.request
from tools.qa.client_lifecycle.services import local_origin


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError('Disposable fixture redirects are forbidden')


def api(stack):
    origin = local_origin(stack.environment['PUBLIC_ORIGIN'])
    client = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ssl._create_unverified_context()),
                                         urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()), NoRedirect())

    def request(path, method='GET', body=None, status=200):
        data = None if body is None else json.dumps(body).encode()
        req = urllib.request.Request(origin+'/api/v1'+path, data=data, method=method,
                                     headers={'Origin': origin, 'Content-Type': 'application/json'})
        with client.open(req, timeout=5) as response:
            if response.status != status:
                raise RuntimeError('Disposable API provisioning status mismatch')
            return None if status == 204 else json.load(response)

    request('/auth/login', 'POST', dict(login='qa_admin', password=stack.password), 204)
    return request
