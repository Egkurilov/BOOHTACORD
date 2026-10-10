import binascii
import struct
import tempfile
import unittest
import zlib
from pathlib import Path

from tools.verify.uiux_visual_diff import compare_png_regions


def write_png(path, width, height, pixels, filter_type=0):
    def chunk(kind, data):
        checksum = binascii.crc32(kind + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", checksum)

    rows = bytearray()
    prior = bytearray(width * 3)
    for y in range(height):
        raw = bytearray()
        for x in range(width):
            raw.extend(pixels[y * width + x])
        rows.append(filter_type)
        for i, value in enumerate(raw):
            left = raw[i - 3] if i >= 3 else 0
            above = prior[i]
            upper_left = prior[i - 3] if i >= 3 else 0
            if filter_type == 0:
                predictor = 0
            elif filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = above
            elif filter_type == 3:
                predictor = (left + above) // 2
            else:
                estimate = left + above - upper_left
                distances = (abs(estimate - left), abs(estimate - above), abs(estimate - upper_left))
                predictor = left if distances[0] <= distances[1] and distances[0] <= distances[2] else (
                    above if distances[1] <= distances[2] else upper_left)
            rows.append((value - predictor) & 255)
        prior = raw
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(rows)))
        + chunk(b"IEND", b"")
    )


class UiuxVisualDiffTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.reference_path = self.root / "reference.png"
        self.actual_path = self.root / "actual.png"
        black = [(0, 0, 0)] * 120
        write_png(self.reference_path, 12, 10, black)
        write_png(self.actual_path, 12, 10, black)

    def tearDown(self):
        self.temporary.cleanup()

    def test_measures_only_named_review_regions(self):
        pixels = [(0, 0, 0)] * 120
        pixels[2 * 12 + 3] = (255, 0, 0)
        pixels[8 * 12 + 10] = (0, 255, 0)
        write_png(self.actual_path, 12, 10, pixels)

        report = compare_png_regions(
            self.reference_path,
            self.actual_path,
            [{"name": "header", "rect": [0, 0, 6, 5]}],
        )

        self.assertEqual(report["status"], "REVIEW_ONLY_NO_APPROVED_GOLDEN")
        self.assertEqual(report["dimensions"], [12, 10])
        header = report["regions"]["header"]
        self.assertEqual(header["comparedPixels"], 30)
        self.assertEqual(header["pixelsChangedOverThreshold"], 1)
        self.assertAlmostEqual(header["meanAbsoluteRgbChange"], 2.833, places=3)

    def test_ignores_dynamic_avatar_region_inside_review_area(self):
        pixels = [(0, 0, 0)] * 120
        pixels[1 * 12 + 1] = (255, 255, 255)
        pixels[2 * 12 + 2] = (255, 0, 0)
        write_png(self.actual_path, 12, 10, pixels)

        report = compare_png_regions(
            self.reference_path,
            self.actual_path,
            [{"name": "toolbar", "rect": [0, 0, 5, 5]}],
            ignore_regions=[{"name": "avatar", "rect": [0, 0, 2, 2]}],
        )

        toolbar = report["regions"]["toolbar"]
        self.assertEqual(toolbar["ignoredPixels"], 4)
        self.assertEqual(toolbar["comparedPixels"], 21)
        self.assertEqual(toolbar["pixelsChangedOverThreshold"], 1)

    def test_decodes_all_standard_png_row_filters(self):
        pixels = [((x * 13) % 256, (y * 23) % 256, ((x + y) * 31) % 256)
                  for y in range(10) for x in range(12)]
        write_png(self.reference_path, 12, 10, pixels, filter_type=0)
        region = [{"name": "all", "rect": [0, 0, 12, 10]}]
        for filter_type in range(5):
            with self.subTest(filter_type=filter_type):
                write_png(self.actual_path, 12, 10, pixels, filter_type=filter_type)
                report = compare_png_regions(self.reference_path, self.actual_path, region)
                self.assertEqual(report["regions"]["all"]["meanAbsoluteRgbChange"], 0)
                self.assertEqual(report["regions"]["all"]["pixelsChangedOverThreshold"], 0)

    def test_rejects_duplicate_names_invalid_regions_and_size_mismatch(self):
        duplicate = [{"name": "header", "rect": [0, 0, 2, 2]}, {"name": "header", "rect": [2, 0, 2, 2]}]
        with self.assertRaisesRegex(ValueError, "unique"):
            compare_png_regions(self.reference_path, self.actual_path, duplicate)
        with self.assertRaisesRegex(ValueError, "within image"):
            compare_png_regions(self.reference_path, self.actual_path, [{"name": "bad", "rect": [11, 9, 2, 2]}])

        mismatch = self.root / "mismatch.png"
        write_png(mismatch, 11, 10, [(0, 0, 0)] * 110)
        with self.assertRaisesRegex(ValueError, "same dimensions"):
            compare_png_regions(self.reference_path, mismatch, [{"name": "header", "rect": [0, 0, 2, 2]}])


if __name__ == "__main__":
    unittest.main()
