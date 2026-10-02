"""Build and validate OCI artifacts with the exact source labels and attestations."""
import subprocess
from tools.verify.oci.verify_oci import verify


def web_build_arguments(environment):
    flag = environment.get("VITE_RNNOISE_ENABLED", "true")
    if flag not in ("true", "false"):
        raise ValueError("VITE_RNNOISE_ENABLED must be true or false")
    return ["--build-arg", "VITE_RNNOISE_ENABLED=" + flag]


def build(source, output, revision, source_hash, environment):
    receipts = {}
    for service, context in (("api", "backend"), ("web", "clients/web")):
        tag = f"voice-platform-{service}:{revision}"
        archive = output / (service + ".oci.tar")
        subprocess.run(["docker", "buildx", "build", "--platform", "linux/amd64",
                        "--label", f"org.opencontainers.image.revision={revision}",
                        "--label", f"org.voice-platform.source-archive-sha256={source_hash}",
                        "--sbom=true", "--provenance=mode=max,version=v0.2", "--load", "--tag", tag,
                        "--output", f"type=oci,dest={archive}",
                        *(web_build_arguments(environment) if service == "web" else []),
                        str(source / context)], env=environment, check=True)
        image_id = subprocess.check_output(["docker", "image", "inspect", "--format", "{{.Id}}", tag], text=True).strip()
        receipts[service] = verify(archive, revision, source_hash, image_id)
    return receipts
