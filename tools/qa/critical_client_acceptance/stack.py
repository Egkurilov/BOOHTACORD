"""Owned real SFU transport for independent connection fault acceptance."""
from tools.audio.livekit_fixture import IMAGE
from tools.qa.client_lifecycle.services import local_docker, ports_available
from tools.qa.client_lifecycle.stack import Stack as Base, ready


class Stack(Base):
    def start(self):
        local_docker()
        ports_available((4880, 4881, 4882))
        config = self.work/'livekit.yaml'
        config.write_text('''port: 4880
bind_addresses: ["127.0.0.1"]
rtc:
  tcp_port: 4881
  udp_port: 4882
  use_external_ip: false
keys:
  qa-only: qa-local-only-secret-12345
webhook:
  api_key: qa-only
  urls: ["http://127.0.0.1:4820/internal/livekit/roster"]
''')
        config.chmod(0o644)
        self.container('sfu', IMAGE, '-v', str(config)+':/qa.yaml:ro', network=False,
                       command=('--config', '/qa.yaml', '--node-ip', '127.0.0.1'))
        ready('http://127.0.0.1:4880')
        super().start()

    def restart(self):
        self.environment['LIVEKIT_PUBLIC_WS_URL'] = 'wss://localhost:4810/qa-sfu'
        super().restart()

    def container(self, role, image, *args, **options):
        if role == 'proxy':
            path = self.work/'Caddyfile'
            path.write_text(path.read_text().replace('  handle /api/* {', '''  handle /qa-sfu* {
    uri strip_prefix /qa-sfu
    reverse_proxy 127.0.0.1:4880
  }
  handle /api/* {'''))
        super().container(role, image, *args, **options)
