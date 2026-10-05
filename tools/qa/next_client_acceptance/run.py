"""Run production composers and protected history against disposable actual services."""
import hashlib
import json
import os
import subprocess
import tempfile
from pathlib import Path
from tools.qa.client_lifecycle.services import run, output
from .stack import Stack


def main():
    root = Path(__file__).resolve().parents[3]
    destination = root/'.out/next-client-acceptance'
    destination.mkdir(parents=True, exist_ok=True)
    run('npm', 'run', 'build', cwd=root/'clients/web', stdout=subprocess.DEVNULL)
    scenarios = []
    for limited in (True, False):
        with tempfile.TemporaryDirectory(prefix='qa-next-client-', dir=root/'.out') as temporary:
            work = Path(temporary)
            stack = Stack(root, work, 2147483648+61000000 if limited else 8*1024**3)
            try:
                stack.start()
                inputs = work/'input.json'
                inputs.write_text(json.dumps(dict(password=stack.password, limited=limited, directory=str(destination))))
                inputs.chmod(0o600)
                private = work/'result.json'
                environment = dict(os.environ, QA_ORIGIN='https://localhost:4810', QA_INPUT=str(inputs),
                                   QA_RESULT=str(private), QA_DB_OWNER=stack.owner)
                run('node', str(root/'tools/qa/next_client_acceptance/scenario.mjs'), env=environment)
                scenarios.append(json.loads(private.read_text()))
                scenarios[-1]['api_binary_sha256'] = hashlib.sha256(stack.binary.read_bytes()).hexdigest()
            finally:
                stack.close()
    report = dict(status='PASS', source_revision=output('git', '-C', str(root), 'rev-parse', 'HEAD'),
                  mocks=False, actual_postgres_and_livekit=True, owned_resources_removed=True, scenarios=scenarios)
    sources = list((root/'tools/qa/next_client_acceptance').glob('*.*'))
    sources += list((root/'clients/web/src/conversation/upload_queue').glob('*.*'))
    sources += list((root/'clients/web/src/conversation/context_position').glob('*.*'))
    sources += [root/'clients/web/src/search/SearchMessageContext.vue', root/'clients/web/src/search/search_context_controller.ts']
    report['source_files'] = {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    report['screenshots'] = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in destination.glob('*.png')}
    (destination/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print('Actual managed uploads and protected unread/context navigation PASS; resources removed')


if __name__ == '__main__':
    main()
