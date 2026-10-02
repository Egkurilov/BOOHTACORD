"""Disposable loopback-only SFU for the real browser microphone gate."""
import subprocess
import time
import uuid
from contextlib import contextmanager
from urllib.request import urlopen

IMAGE = 'livekit/livekit-server:v1.13.7@sha256:6fd3b7088874c4d119160dd688798dfec852bc014786d392caad15f6f63912a3'


@contextmanager
def local_sfu():
    name = 'rnnoise-browser-' + uuid.uuid4().hex[:12]
    subprocess.run(['docker', 'run', '--rm', '-d', '--name', name,
                    '-p', '127.0.0.1:17880:7880/tcp', '-p', '127.0.0.1:17881:17881/tcp',
                    '-p', '127.0.0.1:7882:7882/udp', IMAGE, '--dev', '--bind', '0.0.0.0',
                    '--node-ip', '127.0.0.1', '--port', '7880', '--rtc.tcp_port', '17881'],
                   check=True, stdout=subprocess.DEVNULL)
    try:
        for attempt in range(30):
            try:
                with urlopen('http://127.0.0.1:17880', timeout=1) as response:
                    if response.status != 200: raise RuntimeError('Local SFU unavailable')
                break
            except OSError:
                if attempt == 29: raise RuntimeError('Local SFU readiness timeout')
                time.sleep(1)
        yield
    finally:
        subprocess.run(['docker', 'rm', '-f', name], check=False, capture_output=True)
