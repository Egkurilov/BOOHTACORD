"""Autonomous actual-API in-flight reservation, cancellation, retry and writer acceptance."""
import hashlib
import json
import os
import signal
import subprocess
import tempfile
from pathlib import Path
from tools.qa.client_lifecycle.services import output, run
from .client import Client, finish
from .stack import UploadStack
from .measure import await_reserved, sample, validate


def scenario(root, limited):
    capacity = 2147483648+51000000 if limited else 8*1024**3
    samples, clients, build = [], [], None
    with tempfile.TemporaryDirectory(prefix='qa-upload-', dir=root/'.out') as directory:
        work = Path(directory)
        stack = UploadStack(root, work, capacity)
        try:
            stack.start()
            stack.reject_second_writer()
            client = Client(stack.password)
            channel = client.create_channel()
            peer = client.create_peer(stack.password) if limited else None
            samples.append(sample(stack))
            clients = [client.upload(channel), client.upload(channel)]
            if not limited:
                build = subprocess.Popen(['go', 'build', '-a', '-o', str(work/'independent-api'), './cmd/api'],
                    cwd=root/'backend', env=dict(os.environ, CGO_ENABLED='0', GOMAXPROCS='2'),
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            await_reserved(stack, 50000000, samples, build)
            samples.append(sample(stack, build))
            if limited:
                quota = client.upload(channel)
                try:
                    status = finish(quota)
                    assert status == 429, f'Account concurrency guard expected 429, received {status}'
                finally:
                    quota.close()
                rejected = peer.upload(channel)
                try:
                    status = finish(rejected)
                    assert status == 507, f'Capacity-limited upload expected 507, received {status}'
                finally:
                    rejected.close()
            clients[0].close()
            await_reserved(stack, 25000000, samples, build)
            assert finish(clients[1]) == 201, 'Remaining concurrent upload did not complete'
            await_reserved(stack, 0, samples, build)
            assert finish(client.upload(channel)) == 201, 'Retry after cancellation did not succeed'
            await_reserved(stack, 0, samples, build)
            staging = output('docker', 'exec', stack.keeper, 'sh', '-c', 'find /attachments/staging -type f | wc -l')
            assert staging == '0', 'Staging file was left after cancel/success'
            if build:
                assert build.wait(timeout=180) == 0, 'Independent real build failed'
            validate(samples, limited)
            stack.verify_stop_first_handover()
            return dict(status='PASS', capacity_limited=limited, samples=samples,
                        actual_second_api_rejected=True, canceled_and_success_released=True,
                        retry_status=201, rejection_status=507 if limited else None,
                        same_account_concurrency_status=429 if limited else None,
                        capacity_account_independent=limited,
                        staging_files=0, actual_stop_first_handover_cycles=2,
                        api_binary_sha256=hashlib.sha256(stack.binary.read_bytes()).hexdigest())
        finally:
            for connection in clients:
                connection.close()
            try:
                if build and build.poll() is None:
                    os.killpg(build.pid, signal.SIGTERM)
                    try:
                        build.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        os.killpg(build.pid, signal.SIGKILL)
                        build.wait()
            finally:
                stack.close()


def main():
    root = Path(__file__).resolve().parents[3]
    (root/'.out').mkdir(exist_ok=True)
    run('npm', 'run', 'build', cwd=root/'clients/web', stdout=subprocess.DEVNULL)
    results = [scenario(root, limited) for limited in (False, True)]
    report = dict(status='PASS', source_revision=output('git', '-C', str(root), 'rev-parse', 'HEAD'),
                  actual_disposable_stack=True, owned_resources_removed=True, scenarios=results)
    sources = list((root/'tools/qa/upload_reservations').glob('*.py'))
    sources += list((root/'backend/internal/storage/acquire_writer_lock').glob('*.go'))
    sources += [root/'backend/internal/app/runtime/run.go', root/'tools/qa/client_lifecycle/stack.py', root/'tools/qa/client_lifecycle/services.py']
    report['source_files'] = {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    destination = root/'.out/upload-reservations'
    destination.mkdir(exist_ok=True)
    (destination/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print('Actual upload reservation, writer exclusion, cancellation and retry PASS')


if __name__ == '__main__':
    main()
