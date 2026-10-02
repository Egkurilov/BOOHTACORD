#!/usr/bin/env python3
"""Loopback-only static frontend and transparent API proxy for disposable QA-05."""
from http.client import HTTPConnection
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from sys import argv


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=argv[1], **kwargs)

    def log_message(self, _format, *_args):
        pass

    def do_GET(self):
        if self.path.startswith('/api/'):
            return self.api()
        if not (Path(argv[1]) / self.path.lstrip('/')).is_file():
            self.path = '/index.html'
        return super().do_GET()

    def do_POST(self):
        return self.api()

    def do_PUT(self):
        return self.api()

    def do_PATCH(self):
        return self.api()

    def do_DELETE(self):
        return self.api()

    def api(self):
        length = int(self.headers.get('Content-Length', '0'))
        body = self.rfile.read(length) if length else None
        headers = {key: value for key, value in self.headers.items()
                   if key.lower() not in ('host', 'connection', 'content-length', 'accept-encoding')}
        active = Path('/tmp/qa05_retry_active_path')
        if active.is_file():
            saved_cookie = Path(active.read_text().strip()) / 'cookie'
            if saved_cookie.is_file():
                headers['Cookie'] = saved_cookie.read_text().strip()
        connection = HTTPConnection('127.0.0.1', int(argv[2]), timeout=30)
        try:
            connection.request(self.command, self.path, body, headers)
            response = connection.getresponse()
            payload = response.read()
            self.send_response(response.status)
            for key, value in response.getheaders():
                if key.lower() not in ('connection', 'transfer-encoding', 'content-length'):
                    self.send_header(key, value)
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            if self.command == 'POST' and '/attachments' in self.path:
                print(f'qa05_upload_wire_status={response.status}', flush=True)
        finally:
            connection.close()


if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', int(argv[3])), Handler).serve_forever()
