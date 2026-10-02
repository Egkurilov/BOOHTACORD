"""Rollback only to a retained signed release with identical backend/schema topology."""
import argparse
import signal
from pathlib import Path
from tools.release.bundle.manifest import require
from tools.release.install.locking import installation_lock
from tools.release.install.state import write_receipt
from .preflight import preflight
from .rollout import transition


def interrupted(signum, frame):
    raise InterruptedError('Rollback interrupted; attempting guarded restoration')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('current_revision')
    parser.add_argument('previous_revision')
    parser.add_argument('--release-root', type=Path, default=Path('/opt/voice-platform-releases'))
    parser.add_argument('--public-key', type=Path, default=Path('/etc/voice-platform/release-signing.pub.pem'))
    parser.add_argument('--environment', type=Path, default=Path('/opt/voice-platform/.env'))
    parser.add_argument('--rehearse', action='store_true')
    parser.add_argument('--observe-seconds', type=int, default=30)
    args = parser.parse_args()
    signal.signal(signal.SIGTERM, interrupted)
    require(30 <= args.observe_seconds <= 300, 'Observation window must be 30..300 seconds')
    root = args.release_root.resolve()
    with installation_lock(root):
        current, previous = preflight(root, args.current_revision, args.previous_revision, args.public_key)
        transition(root / args.previous_revision, previous, root / args.current_revision, current, args.environment,
                   rehearse=args.rehearse, observe=args.observe_seconds)
        accepted = current if args.rehearse else previous
        write_receipt(root / accepted['source_revision'], accepted)
        print('Verified rollback completed; running ' + accepted['source_revision'])


if __name__ == '__main__':
    main()
