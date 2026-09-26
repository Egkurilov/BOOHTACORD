#!/usr/bin/env python3
"""Read-only counts for the active disposable QA-05 fixture."""
import json
import subprocess
from pathlib import Path

work = Path(Path('/tmp/qa05_retry_active_path').read_text().strip())
database = (work / 'database').read_text().strip()
query = 'select count(*) from attachments'
rows = int(subprocess.check_output(['runuser', '-u', 'postgres', '--', 'psql', '-d', database, '-Atc', query]))
parts = len(list((work / 'storage' / 'staging').glob('*.part')))
mount = subprocess.check_output(['findmnt', '-n', '-o', 'SIZE', str(work / 'storage')], text=True).strip()
print(json.dumps({'attachment_rows': rows, 'part_files': parts, 'mounted_size': mount}, sort_keys=True))
