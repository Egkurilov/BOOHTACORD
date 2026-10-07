"""Validate issue #173's physical paired-acceptance evidence."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from tools.verify.paired_screen_acceptance.rules import validate_evidence


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: python -m tools.verify.paired_screen_acceptance.validate_evidence <evidence.json>")
        return 2
    try:
        value = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"invalid evidence JSON: {exc}")
        return 2
    errors = validate_evidence(value)
    if errors:
        print("\n".join(errors))
        return 1
    print(f"Issue #173 evidence structure OK; aggregate status: {value['status']}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
