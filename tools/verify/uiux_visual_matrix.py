"""Validate the UIUX-2026 screenshot archive against its review matrix."""

import hashlib
import json
import struct
import sys
from pathlib import Path
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parents[2]
MATRIX_PATH = ROOT / "clients/web/tests/uiux_2026/visual_matrix.json"


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def main() -> int:
    matrix = json.loads(MATRIX_PATH.read_text(encoding="utf-8"))
    archive_path = ROOT / matrix["sourceArchive"]
    archive_bytes = archive_path.read_bytes()
    actual_sha = hashlib.sha256(archive_bytes).hexdigest()
    if actual_sha != matrix["sourceArchiveSha256"]:
        return fail("source archive SHA-256 does not match the pinned review asset")

    screens = matrix["screens"]
    if len(screens) != matrix["expectedCount"] or len(screens) != 41:
        return fail(f"expected 41 catalog rows, got {len(screens)}")
    if len({row["referenceAsset"] for row in screens}) != 41:
        return fail("catalog reference assets must be unique")
    if sum(row["surface"] == "desktop" for row in screens) != 18:
        return fail("expected 18 desktop reference screens")
    if sum(row["surface"] == "mobile" for row in screens) != 23:
        return fail("expected 23 mobile reference screens")

    with ZipFile(archive_path) as archive:
        png_entries = {
            Path(name).name: name
            for name in archive.namelist()
            if name.startswith("ui-ux-screenshots/") and name.lower().endswith(".png")
        }
        if len(png_entries) != 41:
            return fail(f"expected 41 PNGs in archive, got {len(png_entries)}")
        if set(png_entries) != {row["referenceAsset"] for row in screens}:
            return fail("catalog asset names do not exactly match the source archive")

        for row in screens:
            expected_viewport = {"width": 1440, "height": 900} if row["surface"] == "desktop" else {"width": 393, "height": 852}
            if row["targetViewport"] != expected_viewport:
                return fail(f"{row['id']} target CSS viewport differs from source README")
            if row["referenceStatus"] != "PRESENT_IN_ARCHIVE":
                return fail(f"{row['id']} is not marked as present in the archive")

            png = archive.read(png_entries[row["referenceAsset"]])
            if png[:8] != b"\x89PNG\r\n\x1a\n" or len(png) < 24:
                return fail(f"{row['referenceAsset']} is not a valid PNG header")
            width, height = struct.unpack(">II", png[16:24])
            if {"width": width, "height": height} != row["referenceRasterPx"]:
                return fail(f"{row['referenceAsset']} raster dimensions differ from the catalog")

            for key in ("fixture", "testFile", "flutterTestFile"):
                if not (ROOT / row[key]).is_file():
                    return fail(f"{row['id']} references missing {key}: {row[key]}")
            for key in ("interaction", "expectedOrException", "owner"):
                if not row[key].strip():
                    return fail(f"{row['id']} is missing {key}")

    print("PASS: 41 source screenshots verified (18 desktop, 23 mobile), names, CSS/raster sizes, SHA-256, and test mappings")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
