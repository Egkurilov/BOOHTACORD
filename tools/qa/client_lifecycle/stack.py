"""Own one isolated database, Tempo, proxy and API process."""
import os
import secrets
import socket
import ssl
import subprocess
import time
import urllib.request
from pathlib import Path
from .services import LABEL, TEMPO, caddy_config, local_docker, remove_owned, run


def ready(url):
    for _ in range(150):
        try:
            context = ssl._create_unverified_context() if url.startswith('https://localhost:4810/') else None
            with urllib.request.urlopen(url, timeout=1, context=context) as response:
                if response.status == 200:
                    return
        except (OSError, urllib.error.HTTPError):
            time.sleep(.2)
    raise RuntimeError('Disposable service did not become ready')


class Stack:
    def __init__(self, root, work):
        self.root, self.work = root, work
        self.owner = 'qa-client-'+secrets.token_hex(8)
        self.resources, self.api, self.log = [], None, None
        self.password = secrets.token_urlsafe(24)
        self.environment = dict(os.environ, DATABASE_URL=
            'postgres://qa:qa-disposable-only@127.0.0.1:5488/qa?sslmode=disable')

    def container(self, role, image, *args, network=True, command=()):
        name = self.owner+'-'+role
        run('docker', 'run', '-d', '--name', name, '--label', LABEL+'='+self.owner,
            '--cpus=2', '--memory=1g', '--network', self.owner if network else 'host',
            *args, image, *command, stdout=subprocess.DEVNULL)
        self.resources.append(('container', name))

    def start(self):
        local_docker()
        for port in (4810, 4811, 4812, 4820, 5488):
            with socket.socket() as listener:
                listener.bind(('127.0.0.1', port))
        run('docker', 'network', 'create', '--label', LABEL+'='+self.owner,
            self.owner, stdout=subprocess.DEVNULL)
        self.resources.append(('network', self.owner))
        self.container('db', 'postgres:17.6-alpine', '-p', '127.0.0.1:5488:5432',
                       '--tmpfs', '/var/lib/postgresql/data', '-e', 'POSTGRES_DB=qa',
                       '-e', 'POSTGRES_USER=qa', '-e', 'POSTGRES_PASSWORD=qa-disposable-only')
        (self.work/'tempo.yaml').write_text(TEMPO)
        (self.work/'tempo.yaml').chmod(0o644)
        self.container('tempo', 'grafana/tempo:2.10.3', '-p', '127.0.0.1:4811:4318',
                       '-p', '127.0.0.1:4812:3200', '--tmpfs', '/tmp:mode=1777',
                       '-v', str(self.work/'tempo.yaml')+':/etc/tempo.yaml:ro',
                       command=('-config.file=/etc/tempo.yaml',))
        run('docker', 'exec', self.owner+'-db', 'sh', '-c',
            'until pg_isready -U qa -d qa; do sleep .2; done', stdout=subprocess.DEVNULL)
        ready('http://127.0.0.1:4812/ready')
        binaries = Path(os.environ.get('QA_BIN_DIR', str(self.work)))
        for name, package in (('api', 'api'), ('migrate', 'migrate'), ('bootstrap', 'bootstrap_admin')):
            if not (binaries/name).is_file():
                run('go', 'build', '-o', str(binaries/name), './cmd/'+package, cwd=self.root/'backend')
        run(str(binaries/'migrate'), env=self.environment, stdout=subprocess.DEVNULL)
        run(str(binaries/'bootstrap'), '--login', 'qa_admin', '--password-stdin',
            input=self.password+'\n', text=True, env=self.environment, stdout=subprocess.DEVNULL)
        self.environment.update(API_ADDR='127.0.0.1:4820', PUBLIC_ORIGIN='https://localhost:4810',
            ATTACHMENTS_DIRECTORY=str(self.work/'attachments'), LIVEKIT_API_KEY='qa-only',
            LIVEKIT_API_SECRET='qa-local-only-secret-12345', LIVEKIT_PUBLIC_WS_URL='ws://localhost:4880',
            LIVEKIT_PRIVATE_HTTP_URL='http://localhost:4880',
            OTEL_EXPORTER_OTLP_TRACES_ENDPOINT='http://127.0.0.1:4811/v1/traces')
        self.binary = binaries/'api'
        self.restart()
        (self.work/'Caddyfile').write_text(caddy_config(self.root))
        self.container('proxy', 'caddy:2.10.0-alpine', '-v', str(self.root)+':'+str(self.root)+':ro',
                       '-v', str(self.work/'Caddyfile')+':/etc/caddy/Caddyfile:ro', network=False)
        ready('https://localhost:4810/api/v1/health')

    def restart(self):
        self.stop_api()
        self.log = (self.work/'api.log').open('a')
        self.api = subprocess.Popen([str(self.binary)], env=self.environment,
                                    stdout=self.log, stderr=self.log)
        ready('http://127.0.0.1:4820/api/v1/health')

    def stop_api(self):
        if self.api:
            self.api.terminate()
            try:
                self.api.wait(timeout=15)
            except subprocess.TimeoutExpired:
                self.api.kill()
                self.api.wait()
            self.api = None
        if self.log:
            self.log.close()
            self.log = None

    def close(self):
        self.stop_api()
        for kind, name in reversed(self.resources):
            remove_owned(name, self.owner, kind)
        self.resources.clear()
