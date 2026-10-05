"""Loopback-only transport reachability lab, without host firewall mutation."""
import subprocess
import time
import uuid
from contextlib import contextmanager
from urllib.request import urlopen
from tools.audio.livekit_fixture import IMAGE

PROFILES = ('baseline', 'udp-blocked', 'signal-only', 'signal-blocked', 'recovery')


def command(name, profile):
    if profile not in PROFILES:
        raise ValueError('Unknown restricted-network profile')
    args = ['docker', 'run', '--rm', '-d', '--name', name,
            '--label', 'boohtacord.packet=restricted-networks',
            '-p', '127.0.0.1:17880:7880/tcp']
    if profile != 'signal-only':
        args += ['-p', '127.0.0.1:17881:17881/tcp']
    if profile in ('baseline', 'signal-blocked', 'recovery'):
        args += ['-p', '127.0.0.1:7882:7882/udp']
    return args + [IMAGE, '--dev', '--bind', '0.0.0.0', '--node-ip', '127.0.0.1',
                   '--port', '7880', '--rtc.tcp_port', '17881']


@contextmanager
def restricted_sfu(profile):
    name = 'restricted-network-' + uuid.uuid4().hex[:12]
    subprocess.run(command(name, profile), check=True, stdout=subprocess.DEVNULL)
    try:
        for attempt in range(30):
            try:
                with urlopen('http://127.0.0.1:17880', timeout=1) as response:
                    if response.status != 200:
                        raise RuntimeError('Isolated SFU unavailable')
                break
            except OSError:
                if attempt == 29:
                    raise RuntimeError('Isolated SFU readiness timeout')
                time.sleep(1)
        yield
    finally:
        subprocess.run(['docker', 'rm', '-f', name], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
