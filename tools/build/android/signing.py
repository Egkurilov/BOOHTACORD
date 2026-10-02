"""Provision existing Android signing material for one build; never change its identity."""
import base64
from contextlib import contextmanager
import os
from pathlib import Path
import tempfile


@contextmanager
def provision():
    encoded = os.environ.get('BOOHTACORD_ANDROID_KEYSTORE_BASE64')
    if not encoded:
        yield  # Gradle validates existing local key.properties or explicit signing inputs.
        return
    for name in ('KEYSTORE_PASSWORD', 'KEY_ALIAS', 'KEY_PASSWORD'):
        if not os.environ.get('BOOHTACORD_ANDROID_' + name): raise RuntimeError('Required Android signing input is missing: ' + name)
    descriptor, name = tempfile.mkstemp(prefix='boohtacord-signing-', suffix='.jks', dir=os.environ.get('RUNNER_TEMP'))
    previous = os.environ.get('BOOHTACORD_ANDROID_KEYSTORE_FILE')
    try:
        with os.fdopen(descriptor, 'wb') as stream: stream.write(base64.b64decode(encoded, validate=True))
        os.environ['BOOHTACORD_ANDROID_KEYSTORE_FILE'] = name
        yield
    finally:
        Path(name).unlink(missing_ok=True)
        if previous is None: os.environ.pop('BOOHTACORD_ANDROID_KEYSTORE_FILE', None)
        else: os.environ['BOOHTACORD_ANDROID_KEYSTORE_FILE'] = previous
