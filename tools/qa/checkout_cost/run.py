"""Measure clean tracked-tree materialization without changing the working index."""
import argparse
import json
import os
import subprocess
import tempfile
import time
from pathlib import Path


def measure(root, revision, output):
    sha = subprocess.check_output(['git', 'rev-parse', revision], cwd=root, text=True).strip()
    names = subprocess.check_output(['git', 'ls-tree', '-rz', '--name-only', sha], cwd=root).split(b'\0')
    records = []
    for repeat in range(3):
        with tempfile.TemporaryDirectory(prefix='checkout-', dir=output) as temporary:
            temporary = Path(temporary).resolve()
            assert temporary.is_relative_to(output.resolve())
            tree = temporary / 'tree'
            tree.mkdir()
            environment = {**os.environ, 'GIT_INDEX_FILE': str(temporary / 'index')}
            started = time.perf_counter()
            subprocess.run(['git', 'read-tree', sha], cwd=root, env=environment, check=True)
            subprocess.run(['git', '-c', 'core.autocrlf=false', 'checkout-index', '--all',
                            '--prefix=' + tree.as_posix() + '/'], cwd=root, env=environment, check=True)
            records.append(round(time.perf_counter() - started, 6))
    archive = output / (sha + '.source.tar.gz')
    subprocess.run(['git', 'archive', '--format=tar.gz', '--output=' + str(archive), sha], cwd=root, check=True)
    return {'source_revision': sha, 'tracked_files': len(list(filter(None, names))),
            'checkout_seconds': records, 'source_archive_bytes': archive.stat().st_size}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('revisions', nargs='+')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    output = root / '.out/checkout-cost'
    output.mkdir(parents=True, exist_ok=True)
    result = {'method': 'git read-tree and checkout-index into empty directories; local shared object cache; no network clone; LF files',
              'runs': [measure(root, ref, output) for ref in args.revisions]}
    (output / 'measurements.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
