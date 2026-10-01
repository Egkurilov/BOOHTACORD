"""Inspect actual APK identity and signer; preserve the published Android certificate."""
import os
import re
from pathlib import Path
from tools.ci.native.process import output

CERTIFICATE = '394e369de2d566b4897493ee498da2f27745e514c49ca88c6489b0b0a811212b'
APPLICATION = 'ru.boohtacord.app'


def tools_directory():
    sdk = os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME')
    if not sdk: raise RuntimeError('ANDROID_SDK_ROOT or ANDROID_HOME must identify the Android SDK')
    directories = [p for p in (Path(sdk) / 'build-tools').iterdir() if re.fullmatch(r'\d+\.\d+\.\d+', p.name)]
    if not directories: raise RuntimeError('Android build tools are unavailable')
    return max(directories, key=lambda p: tuple(map(int, p.name.split('.'))))


def certificate(text, *, release):
    hashes = re.findall(r'Signer #\d+ certificate SHA-256 digest:\s*([0-9a-f]{64})', text)
    if len(hashes) != 1:
        # apksigner output contains public certificate data, never the private key.
        raise ValueError('Expected exactly one verified APK signer; observed: ' + repr(text[:3000]))
    if release and hashes[0] != CERTIFICATE: raise ValueError('Android release signing identity changed')
    return hashes[0]


def inspect(apk, *, release, version):
    directory = tools_directory()
    signer = directory / ('apksigner.bat' if os.name == 'nt' else 'apksigner')
    fingerprint = certificate(output(str(signer), 'verify', '--print-certs', str(apk)), release=release)
    badging = output(str(directory / ('aapt.exe' if os.name == 'nt' else 'aapt')), 'dump', 'badging', str(apk))
    match = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging)
    if not match or match[1] != APPLICATION or match[3] != version.split('+')[0]:
        raise ValueError('Built APK application ID or version differs')
    return {'certificate_sha256': fingerprint, 'build_tools': directory.name, 'version_code': int(match[2])}
