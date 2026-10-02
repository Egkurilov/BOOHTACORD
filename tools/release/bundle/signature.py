"""Detached RSA/SHA-256 signatures; verification keys come from host trust configuration."""
import subprocess
from pathlib import Path


def signature_path(document: Path):
    return document.with_suffix(document.suffix + ".sig")


def sign(document: Path, private_key: Path, *, openssl="openssl"):
    subprocess.run([openssl, "dgst", "-sha256", "-sign", str(private_key),
                    "-out", str(signature_path(document)), str(document)], check=True, capture_output=True)


def verify(document: Path, trusted_public_key: Path, *, openssl="openssl"):
    result = subprocess.run([openssl, "dgst", "-sha256", "-verify", str(trusted_public_key),
                             "-signature", str(signature_path(document)), str(document)], capture_output=True)
    if result.returncode:
        raise ValueError("Release manifest signature does not match the trusted host key")
