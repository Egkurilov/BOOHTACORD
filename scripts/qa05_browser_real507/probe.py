#!/usr/bin/env python3
"""Probe the real local API across a tmpfs capacity change; no browser upload."""
import json
import subprocess
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

work = Path('/tmp/qa05_retry_active_path').read_text().strip()
storage = Path(work) / 'storage'
origin = 'http://localhost:18796'
cookie = ''


def request(method, path, body=None, content_type='application/json'):
    headers = {'Origin': origin, 'Accept': 'application/json'}
    if body is not None:
        headers['Content-Type'] = content_type
    if cookie:
        headers['Cookie'] = cookie
    try:
        response = urlopen(Request(origin + path, body, headers, method), timeout=15)
    except HTTPError as error:
        response = error
    payload = response.read()
    return response.status, response.headers, json.loads(payload) if payload else None


password = (Path(work) / 'password').read_text().strip()
status, headers, _ = request('POST', '/api/v1/auth/login', json.dumps({'login': 'qa05admin', 'password': password}).encode())
assert status == 204, f'login status {status}'
cookie = headers['Set-Cookie'].split(';', 1)[0]
cookie_file = Path(work) / 'cookie'
cookie_file.write_text(cookie)
cookie_file.chmod(0o600)
status, _, category = request('POST', '/api/v1/admin/categories', b'{"name":"QA05"}')
assert status == 201, f'category status {status}'
status, _, channel = request('POST', f'/api/v1/admin/categories/{category["id"]}/channels', b'{"name":"Capacity retry","kind":"TEXT"}')
assert status == 201, f'channel status {status}'
(Path(work) / 'channel_id').write_text(channel['id'])

file_bytes = b'qa05 synthetic safe\n'
boundary = 'qa05boundary'
multipart = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="qa05-synthetic-safe.txt"\r\n'
             'Content-Type: text/plain\r\n\r\n').encode() + file_bytes + f'\r\n--{boundary}--\r\n'.encode()
path = f'/api/v1/channels/{channel["id"]}/attachments'


def count():
    database = (Path(work) / 'database').read_text().strip()
    output = subprocess.check_output(['runuser', '-u', 'postgres', '--', 'psql', '-d', database, '-Atc', 'select count(*) from attachments'])
    return int(output)


def mount(size):
    subprocess.run(['mount', '-o', f'remount,size={size}', str(storage)], check=True)


before = count()
mount('64M')
status_low, _, body_low = request('POST', path, multipart, f'multipart/form-data; boundary={boundary}')
assert status_low == 507 and body_low['error']['code'] == 'INSUFFICIENT_STORAGE'
assert count() == before
assert not list((storage / 'staging').glob('*.part'))
mount('3G')
status_high, _, body_high = request('POST', path, multipart, f'multipart/form-data; boundary={boundary}')
assert status_high == 201 and body_high['byte_size'] == len(file_bytes)
assert count() == before + 1
assert not list((storage / 'staging').glob('*.part'))
mount('64M')
print(json.dumps({'low_http': status_low, 'high_http': status_high, 'before_rows': before,
                  'after_rows': before + 1, 'part_files': 0, 'browser_headroom': '64M'}, sort_keys=True))
