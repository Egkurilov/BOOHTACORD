"""Build and validate OCI artifacts with the exact source labels and attestations."""
import subprocess
from scripts.qa11_release.verify_oci import verify


def build(source, output, revision, source_hash, environment):
    receipts = {}
    for service, context in (("api", "backend"), ("web", "frontend")):
        tag = f"voice-platform-{service}:{revision}"
        archive = output / (service + ".oci.tar")
        subprocess.run(["docker", "buildx", "build", "--platform", "linux/amd64",
                        "--label", f"org.opencontainers.image.revision={revision}",
                        "--label", f"org.voice-platform.source-archive-sha256={source_hash}",
                        "--sbom=true", "--provenance=mode=max,version=v0.2", "--load", "--tag", tag,
                        "--output", f"type=oci,dest={archive}", str(source / context)], env=environment, check=True)
        image_id = subprocess.check_output(["docker", "image", "inspect", "--format", "{{.Id}}", tag], text=True).strip()
        receipts[service] = verify(archive, revision, source_hash, image_id)
    return receipts
