"""Drop transport only inside the uniquely owned SFU network namespace."""
import os
import subprocess
import sys
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
    if os.environ.get('DOCKER_CONTEXT') or not os.environ.get('DOCKER_HOST'):
        endpoint = subprocess.check_output(['docker', 'context', 'inspect', '--format',
                                           '{{.Endpoints.docker.Host}}'], text=True).strip()
    else:
        endpoint = os.environ['DOCKER_HOST']
    if endpoint != 'unix:///var/run/docker.sock':
        raise RuntimeError('Transport isolation requires the local rootful Docker socket')
    if os.geteuid() != 0:
        subprocess.run(['sudo', '-n', sys.executable, '-m', 'tools.network.restricted.restrict', name, profile], check=True)
        return
    label = subprocess.check_output(['docker', 'inspect', '--format',
                                     '{{ index .Config.Labels "boohtacord.packet" }}', name], text=True).strip()
    if label != 'restricted-networks':
        raise RuntimeError('Refusing an unowned SFU container')
    pid = int(subprocess.check_output(['docker', 'inspect', '--format', '{{.State.Pid}}', name], text=True))
    if pid <= 1:
        raise RuntimeError('Refusing to modify the host network namespace')
    descriptor = os.open(f'/proc/{pid}/ns/net', os.O_RDONLY)
    try:
        if os.fstat(descriptor).st_ino == Path('/proc/self/ns/net').stat().st_ino:
            raise RuntimeError('Refusing to modify the host network namespace')
        # Pin the checked namespace across PID reuse. The parent stays alive
        # while nsenter opens this FD via procfs; sudo need not inherit the FD.
        namespace = f'/proc/{os.getpid()}/fd/{descriptor}'
        for rule in filters:
            subprocess.run(['nsenter', '--net=' + namespace, 'iptables', '-I', 'INPUT', *rule], check=True)
    finally:
        os.close(descriptor)
    # Rules disappear with this container's namespace; no host rule to restore.


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[2] not in ('udp-blocked', 'signal-only'):
        raise SystemExit('Expected owned SFU name and restricted profile')
    restrict(sys.argv[1], sys.argv[2])
