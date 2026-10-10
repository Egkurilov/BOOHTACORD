"""Create a fresh owned deployment, execute a profile, remove every resource."""
import argparse
import json
import os
import platform
import secrets
import subprocess
import tempfile
from pathlib import Path
from tools.load.guard.server import Guard
from tools.load.provision.dataset import provision, validate_count
from tools.qa.client_lifecycle.services import output, ports_available, run
from tools.load.provision.stack import Stack
from .report import render
from .cleanup import cleanup
from .outcome import outcome
from .artifact_identity import api_binary_sha256


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--accounts', type=int, default=4)
    parser.add_argument('--seconds', type=int, default=60)
    parser.add_argument('--profile', choices=('normal', 'reconnect', 'uploads', 'faults', 'nat_auth'), default='normal')
    parser.add_argument('--upload-bytes', type=int, default=1024)
    args = parser.parse_args()
    validate_count(args.accounts)
    if not 10 <= args.seconds <= 7200 or not 1 <= args.upload_bytes <= 25000000:
        raise ValueError('Invalid bounded time or upload size')
    if platform.system() != 'Linux':
        raise ValueError('Owned fixture requires a local Linux Docker daemon and /proc')
    root = Path(__file__).resolve().parents[3]
    destination = root/'.out/backend-load'/args.profile
    destination.mkdir(parents=True, exist_ok=True)
    ports_available((4890,))
    with tempfile.TemporaryDirectory(prefix='boohtacord-load-', dir=root/'.out') as directory:
        stack, guard = Stack(root, Path(directory)), None
        report = dict(schema_version=1, outcome='NOT_RUN', target_capacity='NOT_RUN')
        stage = 'fixture_start'
        try:
            stack.start()
            stage = 'synthetic_provision'
            nonce = secrets.token_hex(32)
            dataset = provision(stack, nonce, args.accounts)
            manifest = dict(Origin='https://localhost:4810', Guard='http://127.0.0.1:4890',
                            Dataset='qa', Nonce=nonce, Owner=stack.owner,
                            Commit=output('git', '-C', str(root), 'rev-parse', 'HEAD'),
                            UploadBytes=args.upload_bytes, MaxRequests=100000, MaxSeconds=args.seconds, **dataset)
            guard = Guard(stack, manifest)
            guard.start()
            stage = 'driver_build'
            binary = Path(directory)/'backend-load'
            run('go', 'build', '-o', str(binary), './cmd/backend-load', cwd=root/'backend')
            stage = 'driver_execute'
            completed = subprocess.run([str(binary), '--profile', args.profile],
                input=json.dumps(manifest), text=True, capture_output=True, timeout=args.seconds+30)
            report['driver'], report['outcome'] = outcome(completed.stdout, completed.returncode)
            report['inventory'] = dict(os=platform.platform(), cpus=os.cpu_count(),
                ram_bytes=os.sysconf('SC_PHYS_PAGES')*os.sysconf('SC_PAGE_SIZE'),
                source_revision=manifest['Commit'], api_sha256=api_binary_sha256(stack, Path(directory)),
                postgres='17.6', sfu='1.13.7', network='loopback TCP API; media NOT_RUN',
                synthetic_accounts=args.accounts, voice_rooms=len(dataset['Voice']), upload_bytes=args.upload_bytes)
            report['exit_code'] = completed.returncode
        except Exception:
            report.update(outcome='FAIL', failure_stage=stage)
        finally:
            try:
                if guard:
                    guard.close()
            except Exception:
                report.update(outcome='FAIL', failure_stage='guard_cleanup')
            finally:
                report.update(cleanup(stack))
                if report['cleanup_failures'] or not report['owned_resources_removed']:
                    report.update(outcome='FAIL', failure_stage='owned_resource_cleanup')
                (destination/'report.json').write_text(json.dumps(report, indent=2)+'\n')
                render(destination, report)
    print('Backend load result '+report['outcome']+'; report='+str(destination/'report.json'))
    return 0 if report['outcome'] == 'PASS' and report.get('exit_code') == 0 else 1


if __name__ == '__main__':
    raise SystemExit(main())
