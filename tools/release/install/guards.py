"""Fail closed before installation and before declaring a release healthy."""
from tools.release.bundle.manifest import require


def disk_budget(available, payload_bytes):
    require(payload_bytes > 0, "Empty release bundle")
    require(available >= payload_bytes * 4 + 2_147_483_648,
            "Insufficient space for extraction, image import and protected reserve")


def installed_digests(expected, loaded, running, configured, service):
    require(loaded == expected, service + " loaded image differs from verified OCI index")
    require(running == expected, service + " running image differs from verified OCI index")
    require(configured == f"voice-platform-{service}@{expected}", service + " does not use the pinned digest")


def writer_topology(configuration, running):
    api = configuration.get('services', {}).get('api')
    require(isinstance(api, dict), 'API topology is unavailable')
    deployment = api.get('deploy', {})
    # Previously signed Compose releases use the native one-replica/stop-first defaults.
    require(deployment.get('replicas', 1) == 1, 'Exactly one API attachment writer is supported')
    for action in ('update_config', 'rollback_config'):
        require(deployment.get(action, {}).get('order', 'stop-first') == 'stop-first',
                'API rollout and rollback must stop the previous writer first')
    require(len([line for line in running.splitlines() if line.strip()]) <= 1,
            'Multiple running API writers; installation is prohibited')
