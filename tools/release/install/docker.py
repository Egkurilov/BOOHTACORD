"""Docker operations available to the installer: import, inspect, and guarded rollout."""
import json
import os
import subprocess
from .guards import installed_digests
from tools.release.bundle.manifest import require


def docker(*args):
    return subprocess.check_output(["docker", *args], text=True).strip()


def load_images(directory, manifest):
    for service, component in manifest["components"].items():
        docker("load", "--input", str(directory / component["archive"]))
        digest = component["index_digest"]
        actual = docker("image", "inspect", "--format", "{{.Id}}", digest)
        require(actual == digest, "Imported OCI index differs")
        tag = f"voice-platform-{service}:{manifest['source_revision']}"
        docker("tag", digest, tag)
        require(docker("image", "inspect", "--format", "{{.Id}}", f"voice-platform-{service}@{digest}") == digest,
                "Digest-qualified local image reference is unavailable")
        (directory / (service + ".oci.json")).write_text(json.dumps({
            **component, "revision": manifest["source_revision"], "source_archive_sha256": manifest["source_archive_sha256"]
        }, sort_keys=True) + "\n", encoding="utf-8")


def deploy(directory, manifest):
    environment = {**os.environ, "VOICE_PLATFORM_DIR": str(directory)}
    for service, component in manifest["components"].items():
        environment[service.upper() + "_IMAGE"] = f"voice-platform-{service}@{component['index_digest']}"
    subprocess.run(["bash", str(directory / "scripts/deploy-images.sh")], env=environment, check=True)


def verify_running(directory, manifest):
    for service, component in manifest["components"].items():
        digest = component["index_digest"]
        container = docker("compose", "--project-directory", str(directory), "-f", str(directory / "compose.yaml"), "ps", "-q", service)
        require(bool(container) and "\n" not in container, "Expected one running " + service)
        installed_digests(digest, docker("image", "inspect", "--format", "{{.Id}}", f"voice-platform-{service}@{digest}"),
                          docker("inspect", "--format", "{{.Image}}", container),
                          docker("inspect", "--format", "{{.Config.Image}}", container), service)
