"""Run actual Chromium/SFU measurements and retain anonymous source-bound data."""
import json
import os
import platform
import subprocess
import sys
from datetime import datetime, timezone
from tools.ci.native.process import ROOT, client, run, output
from .sfu import IMAGE, PROFILES, restricted_sfu


def main():
    run(sys.executable, '-m', 'unittest', 'tools.network.restricted.test_sfu',
        'tools.network.restricted.test_restrict')
    destination = ROOT / '.out/restricted-networks'
    destination.mkdir(parents=True, exist_ok=True)
    revision = output('git', 'rev-parse', 'HEAD')
    rows = []
    for profile in PROFILES:
        path = destination / f'{profile}.json'
        path.unlink(missing_ok=True)
        env = {**os.environ, 'NETWORK_PROFILE': profile, 'NETWORK_REPORT_PATH': str(path)}
        with restricted_sfu(profile):
            result = subprocess.run(['npm.cmd' if os.name == 'nt' else 'npm', 'run',
                                     'test:restricted-networks'], cwd=client('web'), env=env)
        if result.returncode:
            raise SystemExit(result.returncode)
        rows.append(json.loads(path.read_text(encoding='utf-8')))
    report = {'sourceRevision': revision, 'measuredAt': datetime.now(timezone.utc).isoformat(),
              'platform': platform.system(), 'livekitImage': IMAGE, 'rows': rows,
              'mechanism': 'owned SFU namespace INPUT drops UDP / ICE TCP; published mappings also omitted; signal-blocked uses an unbound loopback socket',
              'physicalHome': 'NOT_RUN', 'physicalHotspot': 'NOT_RUN',
              'productionAdmissionRevocation': 'NOT_RUN', 'capacity': 'NOT_RUN'}
    (destination / 'matrix.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('Restricted-network matrix measured; physical home/hotspot remain NOT_RUN')


if __name__ == '__main__':
    main()
