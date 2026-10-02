"""Switch verified images; restore once on failure while resource identity agrees."""
import time
from tools.release.install.docker import load_images, deploy, verify_running
from tools.release.install.runtime import prepare_environment
from .identity import identities


def apply(directory, manifest, environment):
    prepare_environment(directory, environment)
    load_images(directory, manifest)
    deploy(directory, manifest)
    verify_running(directory, manifest)


def transition(previous_dir, previous, current_dir, current, environment, *, rehearse=False, observe=30):
    baseline = identities()
    restore_attempted = False
    try:
        apply(previous_dir, previous, environment)
        if identities() != baseline:
            raise RuntimeError('Resource identity changed; operator diagnosis required')
        if rehearse:
            time.sleep(observe)
            if identities() != baseline:
                raise RuntimeError('Resource identity changed; operator diagnosis required')
            restore_attempted = True
            apply(current_dir, current, environment)
            if identities() != baseline:
                raise RuntimeError('Resource identity changed; operator diagnosis required')
    except BaseException:
        if not restore_attempted:
            if identities() != baseline:
                raise RuntimeError('Resource identity changed; automatic restore is prohibited')
            apply(current_dir, current, environment)
            if identities() != baseline:
                raise RuntimeError('Resource identity changed during restore; operator diagnosis required')
        raise
