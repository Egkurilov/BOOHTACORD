"""One host lock shared by installation, resume and rollback."""
from contextlib import contextmanager


@contextmanager
def installation_lock(root):
    import fcntl
    root.mkdir(mode=0o750, parents=True, exist_ok=True)
    with (root / '.install.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield
