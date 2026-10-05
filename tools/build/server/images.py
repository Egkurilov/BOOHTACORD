"""Build and validate OCI artifacts with the exact source labels and attestations."""
import subprocess
from urllib.parse import urlsplit
from tools.verify.oci.verify_oci import verify


def web_build_arguments(environment):
    flag = environment.get("VITE_RNNOISE_ENABLED", "true")
    if flag not in ("true", "false"):
        raise ValueError("VITE_RNNOISE_ENABLED must be true or false")
    value = environment.get("VITE_PUBLIC_ORIGIN", "").strip()
    try:
        origin = urlsplit(value)
        port = origin.port
    except ValueError as error:
        raise ValueError("VITE_PUBLIC_ORIGIN must be a valid HTTPS origin") from error
    host = (origin.hostname or "").lower()
    if (origin.scheme.lower() != "https" or not host or origin.username or origin.password
            or port == 0 or origin.path not in ("", "/") or origin.query or origin.fragment):
        raise ValueError("VITE_PUBLIC_ORIGIN must be an HTTPS origin without credentials or a path")
    authority = f"[{host}]" if ":" in host else host
    if port and port != 443:
        authority += f":{port}"
    return ["--build-arg", "VITE_RNNOISE_ENABLED=" + flag,
            "--build-arg", "VITE_PUBLIC_ORIGIN=https://" + authority]


def build(source, output, revision, source_hash, environment):
    receipts = {}
    for service, context in (("api", "backend"), ("web", ".")):
        tag = f"voice-platform-{service}:{revision}"
        archive = output / (service + ".oci.tar")
        subprocess.run(["docker", "buildx", "build", "--platform", "linux/amd64",
                        "--label", f"org.opencontainers.image.revision={revision}",
                        "--label", f"org.voice-platform.source-archive-sha256={source_hash}",
                        "--sbom=true", "--provenance=mode=max,version=v0.2", "--load", "--tag", tag,
                        "--output", f"type=oci,dest={archive}",
                        *( ["--file", str(source / "clients/web/Dockerfile"), *web_build_arguments(environment),
                            "--build-arg", "SOURCE_REVISION=" + revision] if service == "web" else []),
                        str(source / context)], env=environment, check=True)
        image_id = subprocess.check_output(["docker", "image", "inspect", "--format", "{{.Id}}", tag], text=True).strip()
        receipts[service] = verify(archive, revision, source_hash, image_id)
    return receipts
