"""Identity observations never create, remove or restore persistent data."""
from tools.release.install.docker import docker


def identities():
    observed = {}
    for name in ('postgres-data', 'attachments-data', 'caddy-data', 'caddy-config'):
        observed['volume:' + name] = docker('volume', 'inspect', '--format',
            '{{.Name}}|{{.Driver}}|{{.Mountpoint}}|{{.CreatedAt}}', 'voice-platform_' + name)
    for name in ('edge', 'private'):
        observed['network:' + name] = docker('network', 'inspect', '--format',
            '{{.Name}}|{{.Id}}', 'voice-platform_' + name)
    return observed
