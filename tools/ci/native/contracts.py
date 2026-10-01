"""Execute the project-owned contract and traceability checks."""
import sys
from .process import run


def main():
    run(sys.executable, "-m", "tools.verify.toolchains.check")
    run(sys.executable, "-m", "tools.verify.python_tests.run")
    run(sys.executable, "-m", "tools.verify.dependencies.dart")
    for name in ("verify-contracts", "verify-spec-traceability", "verify-github-workflows", "verify-ci-sbom"):
        run("pwsh", "-NoProfile", "-File", f"scripts/{name}.ps1")
    run("docker", "compose", "--env-file", ".env.example", "-f", "compose.yaml", "config", "--quiet")
    for name in ("verify-otel-egress", "verify-compose-images"):
        run("pwsh", "-NoProfile", "-File", f"scripts/{name}.ps1")


if __name__ == "__main__":
    main()
