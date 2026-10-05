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
    records = re.findall(r'(?m)^(Signer #\d+|V[123](?:\.1)? Signer:) certificate SHA-256 digest: '
                         r'([0-9a-fA-F]{64})\s*$', text)
    labels = [label for label, _ in records]
    hashes = {digest.lower() for _, digest in records}
    numbered = any(label.startswith('Signer #') for label in labels)
    if (len(hashes) != 1 or len(labels) != len(set(labels)) or
            (numbered and labels != ['Signer #1'])):
        # apksigner output contains public certificate data, never the private key.
        raise ValueError('Expected exactly one verified APK signer; observed: ' + repr(text[:3000]))
    fingerprint = hashes.pop()
    if release and fingerprint != CERTIFICATE: raise ValueError('Android release signing identity changed')
    return fingerprint


def inspect(apk, *, release, version):
    directory = tools_directory()
    signer = directory / ('apksigner.bat' if os.name == 'nt' else 'apksigner')
    fingerprint = certificate(output(str(signer), 'verify', '--print-certs', str(apk)), release=release)
    badging = output(str(directory / ('aapt.exe' if os.name == 'nt' else 'aapt')), 'dump', 'badging', str(apk))
    match = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging)
    if not match or match[1] != APPLICATION or match[3] != version.split('+')[0]:
        raise ValueError('Built APK application ID or version differs')
    build = version.split('+')
    if len(build) != 2 or not re.fullmatch(r'[1-9][0-9]*', build[1]):
        raise ValueError('Expected a canonical positive APK build number')
    native = re.search(r'(?m)^native-code: (.+)$', badging)
    arches = re.findall(r"'([^']+)'", native[1]) if native else []
    offsets = {'armeabi-v7a': 1000, 'arm64-v8a': 2000, 'x86_64': 4000}
    if any(arch not in offsets for arch in arches):
        raise ValueError('Built APK contains an unsupported ABI')
    expected = int(build[1]) + (offsets[arches[0]] if len(arches) == 1 else 0)
    if int(match[2]) != expected:
        raise ValueError('Built APK version code differs from its build number and ABI')
    return {'certificate_sha256': fingerprint, 'build_tools': directory.name, 'version_code': int(match[2])}
