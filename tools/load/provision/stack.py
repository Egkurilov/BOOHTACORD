"""Fresh-source fixture with no inherited production telemetry credentials."""
import ipaddress
import json
import os
from tools.qa.critical_client_acceptance.stack import Stack as ExistingStack
from tools.qa.client_lifecycle.services import output


def network_gateway_cidrs(name):
    networks = json.loads(output('docker', 'network', 'inspect', name))
    if not networks:
        raise ValueError('Disposable fixture proxy network is unavailable')
    configs = networks[0].get('IPAM', {}).get('Config', [])
    cidrs = []
    for config in configs:
        gateway = config.get('Gateway')
        if gateway:
            address = ipaddress.ip_address(gateway)
            cidrs.append(f'{address}/{address.max_prefixlen}')
    if not cidrs:
        raise ValueError('Disposable fixture proxy network has no gateway')
    return cidrs


class Stack(ExistingStack):
    def __init__(self, root, work):
        if os.environ.get('QA_BIN_DIR'):
            raise ValueError('External fixture binaries cannot attest this checkout')
        super().__init__(root, work)
        self.environment = {name: value for name, value in self.environment.items()
                            if not name.startswith('OTEL_')}
        self.environment['TRUSTED_PROXY_CIDRS'] = '127.0.0.1/32'

    def seed_admin_members(self):
        """Keep the database single-admin until load accounts are provisioned."""

    def start_api(self):
        trusted = ['127.0.0.1/32']
        for network in ('bridge', self.owner):
            trusted.extend(network_gateway_cidrs(network))
        self.environment['TRUSTED_PROXY_CIDRS'] = ','.join(dict.fromkeys(trusted))
        super().start_api()
