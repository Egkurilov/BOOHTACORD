"""Generate the lazy emoji catalog from Unicode's published emoji-test data.

Source: https://www.unicode.org/Public/emoji/latest/emoji-test.txt
Copyright © Unicode, Inc. Licensed under the Unicode License v3:
https://www.unicode.org/license.txt
"""

import json
import urllib.request
from pathlib import Path


SOURCE = "https://www.unicode.org/Public/emoji/latest/emoji-test.txt"
TARGET = Path(__file__).resolve().parents[2] / "src/conversation/emoji_full_catalog.json"


def main() -> None:
    request = urllib.request.Request(SOURCE, headers={"User-Agent": "BOOHTACORD catalog generator"})
    with urllib.request.urlopen(request, timeout=30) as response:
        lines = response.read().decode("utf-8").splitlines()
    group = ""
    entries: list[dict[str, str]] = []
    for line in lines:
        if line.startswith("# group: "):
            group = line.removeprefix("# group: ")
            continue
        if "; fully-qualified" not in line or " # " not in line:
            continue
        codepoints, annotation = line.split(";", 1)
        glyph = "".join(chr(int(codepoint, 16)) for codepoint in codepoints.split())
        description = annotation.split(" # ", 1)[1].strip()
        name = description.split(" ", 2)[2]
        entries.append({"emoji": glyph, "name": name, "group": group})
    if len(entries) < 3000:
        raise RuntimeError(f"Unexpected Unicode catalog size: {len(entries)}")
    TARGET.write_text(json.dumps(entries, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"Wrote {len(entries)} fully-qualified emoji to {TARGET}")


if __name__ == "__main__":
    main()
