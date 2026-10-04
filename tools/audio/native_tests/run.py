"""Execute the shared native DSP tests used by Web and Flutter capture."""
from tools.ci.native.process import ROOT, run


def main():
    source = ROOT / 'clients/flutter/packages/flutter_webrtc/common/rnnoise'
    build = ROOT / '.out/checks/audio-native'
    run('cmake', '-S', str(source), '-B', str(build),
        '-DBOOHTA_RNNOISE_TESTS=ON', '-DCMAKE_BUILD_TYPE=Release')
    run('cmake', '--build', str(build), '--config', 'Release', '--parallel', '2')
    run('ctest', '--test-dir', str(build), '-C', 'Release',
        '--no-tests=error', '--output-on-failure')


if __name__ == '__main__':
    main()
