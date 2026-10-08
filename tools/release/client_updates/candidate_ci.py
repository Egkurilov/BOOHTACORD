"""Dispatch and await full CI for an exact Windows catalog candidate commit."""
import argparse
import json
import re
import subprocess
import sys
import time


def dispatch_and_wait(branch, sha, repository, *, command=subprocess.run,
                      sleep=time.sleep, registration_attempts=24, run_attempts=360):
    if (not re.fullmatch(r"codex/windows-catalog-[A-Za-z0-9._-]+", branch)
            or not re.fullmatch(r"[0-9a-f]{40}", sha)
            or not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository)):
        raise RuntimeError("invalid candidate branch, commit, or repository")

    def invoke(args, failure, capture=True):
        try:
            result = command(args, text=True, capture_output=capture)
        except OSError as error:
            raise RuntimeError(f"GitHub CLI unavailable; {failure}; no PR was created") from error
        if result.returncode:
            raise RuntimeError(f"{failure}; no PR was created")
        return result

    dispatch = ["gh", "workflow", "run", "ci.yaml", "--ref", branch, "--repo", repository]
    print(f"Dispatching full CI for candidate {branch} at {sha}.", file=sys.stderr, flush=True)
    invoke(dispatch, "CI dispatch failed; check workflow_dispatch and token actions:write")
    listing = ["gh", "run", "list", "--workflow", "ci.yaml", "--branch", branch,
               "--commit", sha, "--event", "workflow_dispatch", "--limit", "20",
               "--json", "databaseId,headSha,headBranch,event", "--repo", repository]
    run_id = None
    for attempt in range(registration_attempts):
        runs = json.loads(invoke(listing, "CI lookup failed; check token actions:write").stdout)
        matched = [run for run in runs if run.get("headSha") == sha
                   and run.get("headBranch") == branch and run.get("event") == "workflow_dispatch"
                   and type(run.get("databaseId")) is int]
        if matched:
            run_id = max(matched, key=lambda run: run["databaseId"])["databaseId"]
            break
        if attempt + 1 < registration_attempts:
            print("Waiting for the exact candidate CI run to register.", file=sys.stderr, flush=True)
            sleep(5)
    if run_id is None:
        raise RuntimeError(f"No CI run registered for candidate {sha} after dispatch; no PR was created")

    url = f"https://github.com/{repository}/actions/runs/{run_id}"
    view = ["gh", "run", "view", str(run_id), "--json",
            "databaseId,headSha,headBranch,event,status,conclusion", "--repo", repository]
    for attempt in range(run_attempts):
        result = json.loads(invoke(view, "CI status lookup failed; check token actions:write").stdout)
        if (result.get("databaseId") != run_id or result.get("headSha") != sha
                or result.get("headBranch") != branch or result.get("event") != "workflow_dispatch"):
            raise RuntimeError(f"CI run identity changed; inspect {url}; no PR was created")
        if result.get("status") == "completed":
            if result.get("conclusion") != "success":
                raise RuntimeError(f"Candidate CI did not pass; inspect {url}; no PR was created")
            print(f"Candidate CI passed: {url}", file=sys.stderr)
            return url
        if attempt + 1 < run_attempts:
            print(f"Candidate CI is {result.get('status', 'unknown')}; waiting: {url}",
                  file=sys.stderr, flush=True)
            sleep(15)
    raise RuntimeError(f"Candidate CI did not complete within the wait limit; inspect {url}; no PR was created")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--branch", required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--repository", required=True)
    args = parser.parse_args()
    print(dispatch_and_wait(args.branch, args.sha, args.repository))


if __name__ == "__main__":
    main()
