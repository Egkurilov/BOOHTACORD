"""Run a real gate and retain its result for the exact checked-out source SHA."""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from tools.ci.native.process import ROOT, output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("gate", choices=("backend", "web", "contracts"))
    args = parser.parse_args()
    revision = output("git", "rev-parse", "HEAD")
    if os.environ.get("GITHUB_SHA", revision) != revision:
        raise RuntimeError("CI source SHA differs from checkout")
    subprocess.run(["git", "diff", "--exit-code", "HEAD", "--"], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    result = subprocess.run([sys.executable, "-m", "tools.ci.native." + args.gate], cwd=ROOT)
    destination = ROOT / ".out/checks"
    destination.mkdir(parents=True, exist_ok=True)
    (destination / f"{args.gate}.json").write_text(json.dumps({
        "source_revision": revision, "gate": args.gate, "status": "PASS" if result.returncode == 0 else "FAIL"
    }, sort_keys=True) + "\n", encoding="utf-8")
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
