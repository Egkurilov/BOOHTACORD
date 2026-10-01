#!/usr/bin/env python3
"""Reject skipped or failed tests in a Go JSON test event stream."""

import json
import sys


def main() -> int:
    passed = set()
    skipped = set()
    failed = set()
    packages_failed = set()
    with open(sys.argv[1], encoding="utf-8") as stream:
        for line in stream:
            event = json.loads(line)
            action = event.get("Action")
            package = event.get("Package", "")
            test = event.get("Test")
            if test:
                label = f"{package}/{test}"
                if action == "pass":
                    passed.add(label)
                elif action == "skip":
                    skipped.add(label)
                elif action == "fail":
                    failed.add(label)
            elif action == "fail":
                packages_failed.add(package)
    print(f"Go tests: {len(passed)} passed, {len(skipped)} skipped, {len(failed)} failed")
    for label in sorted(skipped):
        print(f"SKIP {label}", file=sys.stderr)
    for label in sorted(failed):
        print(f"FAIL {label}", file=sys.stderr)
    for package in sorted(packages_failed):
        print(f"FAIL package {package}", file=sys.stderr)
    return 1 if skipped or failed or packages_failed or not passed else 0


if __name__ == "__main__":
    raise SystemExit(main())
