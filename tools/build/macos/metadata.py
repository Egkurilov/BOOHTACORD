"""Describe the verified app signature beside its packaged macOS archive."""
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path
from tools.ci.native.process import output
from tools.release.native_artifact.manifest import digest, write


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('app', type=Path)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    if sys.platform != 'darwin': raise RuntimeError('macOS signing inspection requires macOS')
    subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(args.app)], check=True)
    details = subprocess.check_output(['/usr/bin/codesign', '-dv', '--verbose=4', str(args.app)],
                                      stderr=subprocess.STDOUT, text=True)
    signing = {'status': 'adhoc'}
    if 'Signature=adhoc' not in details:
        with tempfile.TemporaryDirectory(prefix='macos-public-cert-') as temporary:
            prefix = str(Path(temporary) / 'signer')
            subprocess.run(['/usr/bin/codesign', '-d', '--extract-certificates', prefix, str(args.app)], check=True)
            certificate = Path(prefix + '0')
            if not certificate.is_file(): raise ValueError('Signing certificate is unavailable')
            signing = {'status': 'signed', 'certificate_sha256': digest(certificate)}
    application = output('/usr/bin/plutil', '-extract', 'CFBundleIdentifier', 'raw', '-o', '-', str(args.app / 'Contents/Info.plist'))
    write(args.directory, 'macos', ['arm64', 'x86_64'], application, signing)


if __name__ == '__main__': main()
