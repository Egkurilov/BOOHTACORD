"""Identify the API executable built into the owned disposable container."""
import hashlib
import subprocess
from pathlib import Path
from tools.load.guard.ownership import owned
from tools.qa.client_lifecycle.services import run


def api_binary_sha256(stack, destination):
    container = owned(stack, 'api')
    binary = Path(destination)/'api'
    run('docker', 'cp', container+':/api', str(binary), stdout=subprocess.DEVNULL)
    return hashlib.sha256(binary.read_bytes()).hexdigest()
