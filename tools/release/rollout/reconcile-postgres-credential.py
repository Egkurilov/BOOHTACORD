#!/usr/bin/env python3
"""Repair a drifted PostgreSQL login only after a private TCP auth failure."""
import json
import os
import subprocess
import sys
from pathlib import Path


def main(project_dir):
    project_dir = Path(project_dir).resolve()
    compose_dir = project_dir / "deploy" if (project_dir / "deploy/compose.yaml").is_file() else project_dir
    compose = ["docker", "compose", "--project-directory", str(compose_dir), "--env-file",
               str(project_dir / ".env"), "-f", str(compose_dir / "compose.yaml")]
    config = subprocess.run(compose + ["config", "--format", "json"], capture_output=True, text=True)
    if config.returncode:
        print("PostgreSQL recovery preflight could not read the Compose configuration.", file=sys.stderr)
        return 1
    environment = json.loads(config.stdout)["services"]["postgres"]["environment"]
    user = str(environment["POSTGRES_USER"])
    database = str(environment["POSTGRES_DB"])
    password = str(environment["POSTGRES_PASSWORD"])
    probe = compose + ["run", "--rm", "--no-deps", "-e", "PGPASSWORD", "--entrypoint", "psql",
                       "postgres", "-h", "postgres", "-U", user, "-d", database,
                       "-v", "ON_ERROR_STOP=1", "-Atqc", "SELECT 1"]
    probe_env = os.environ.copy()
    probe_env["PGPASSWORD"] = password
    result = subprocess.run(probe, capture_output=True, text=True, env=probe_env)
    if result.returncode == 0 and result.stdout.strip() == "1":
        print("PostgreSQL TCP authentication works; no database credential was changed.")
        return 0
    if "password authentication failed" not in result.stderr.lower():
        print("PostgreSQL TCP preflight failed outside password authentication; no database credential was changed.",
              file=sys.stderr)
        return 1
    password_input = f"\\password\n{password}\n{password}\n"
    repair = subprocess.run(compose + ["exec", "-T", "postgres", "psql", "-U", user, "-d", database,
                                       "-v", "ON_ERROR_STOP=1"], input=password_input, capture_output=True, text=True)
    if repair.returncode:
        print("PostgreSQL rejected the guarded role credential repair; no app services were changed.",
              file=sys.stderr)
        return 1
    result = subprocess.run(probe, capture_output=True, text=True, env=probe_env)
    if result.returncode or result.stdout.strip() != "1":
        print("PostgreSQL TCP authentication still fails after the guarded credential repair.", file=sys.stderr)
        return 1
    print("PostgreSQL login synchronized to the host deployment environment and verified over the private network.")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: reconcile-postgres-credential.py PROJECT_DIR")
    raise SystemExit(main(sys.argv[1]))
