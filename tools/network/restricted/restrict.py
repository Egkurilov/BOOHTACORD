"""Drop transport only inside the uniquely owned SFU network namespace."""
import os
import subprocess
from pathlib import Path


def rules(profile):
    result = []
    if profile in ('udp-blocked', 'signal-only'):
        result.append(['-p', 'udp', '-j', 'DROP'])
    if profile == 'signal-only':
        result.append(['-p', 'tcp', '--dport', '17881', '-j', 'DROP'])
    return result


def restrict(name, profile):
    filters = rules(profile)
    if not filters:
        return
    if not name.startswith('restricted-network-') or os.name != 'posix':
        raise RuntimeError('Transport isolation requires the owned Linux SFU')
    pid = int(subprocess.check_output(['docker', 'inspect', '--format', '{{.State.Pid}}', name], text=True))
    if pid <= 1 or Path(f'/proc/{pid}/ns/net').stat().st_ino == Path('/proc/self/ns/net').stat().st_ino:
        raise RuntimeError('Refusing to modify the host network namespace')
    privilege = [] if os.geteuid() == 0 else ['sudo', '-n']
    for rule in filters:
        subprocess.run([*privilege, 'nsenter', '--target', str(pid), '--net',
                        'iptables', '-I', 'INPUT', *rule], check=True)
    # Rules disappear with this container's namespace; no host rule to restore.
