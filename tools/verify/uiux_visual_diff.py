"""Create review-only, region-scoped PNG deltas without inventing golden thresholds."""

import argparse
import binascii
import hashlib
import json
import struct
import sys
import zlib
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _decode_png(path):
    data = Path(path).read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"{path}: not a PNG")

    cursor = len(PNG_SIGNATURE)
    header = None
    image_data = bytearray()
    saw_end = False
    while cursor < len(data):
        if cursor + 12 > len(data):
            raise ValueError(f"{path}: truncated PNG chunk")
        length = struct.unpack_from(">I", data, cursor)[0]
        kind = data[cursor + 4:cursor + 8]
        start = cursor + 8
        end = start + length
        if end + 4 > len(data):
            raise ValueError(f"{path}: truncated PNG chunk data")
        payload = data[start:end]
        expected_crc = struct.unpack_from(">I", data, end)[0]
        if binascii.crc32(kind + payload) & 0xFFFFFFFF != expected_crc:
            raise ValueError(f"{path}: invalid PNG chunk checksum")
        if kind == b"IHDR":
            if header is not None or length != 13:
                raise ValueError(f"{path}: invalid PNG header")
            header = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            image_data.extend(payload)
        elif kind == b"IEND":
            saw_end = True
            break
        cursor = end + 4

    if header is None or not saw_end:
        raise ValueError(f"{path}: incomplete PNG")
    width, height, bit_depth, color_type, compression, filtering, interlace = header
    channels = {2: 3, 6: 4}.get(color_type)
    if not width or not height or bit_depth != 8 or channels is None or compression or filtering or interlace:
        raise ValueError(f"{path}: expected non-interlaced 8-bit RGB/RGBA PNG")

    stride = width * channels
    try:
        decoded = zlib.decompress(image_data)
    except zlib.error as error:
        raise ValueError(f"{path}: invalid PNG image data") from error
    if len(decoded) != height * (stride + 1):
        raise ValueError(f"{path}: decoded PNG data has an unexpected size")

    rgb = bytearray(width * height * 3)
    prior = bytearray(stride)
    position = 0
    for y in range(height):
        filter_type = decoded[position]
        position += 1
        source = decoded[position:position + stride]
        position += stride
        row = bytearray(stride)
        if filter_type > 4:
            raise ValueError(f"{path}: unsupported PNG filter {filter_type}")
        for i, value in enumerate(source):
            left = row[i - channels] if i >= channels else 0
            above = prior[i]
            upper_left = prior[i - channels] if i >= channels else 0
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
            row[i] = (value + predictor) & 255

        target = y * width * 3
        if channels == 3:
            rgb[target:target + width * 3] = row
        else:
            for x in range(width):
                source_pixel = x * 4
                target_pixel = target + x * 3
                rgb[target_pixel:target_pixel + 3] = row[source_pixel:source_pixel + 3]
        prior = row
    return width, height, bytes(rgb)


def _rect(entry, width, height, group):
    name = entry.get("name")
    rect = entry.get("rect")
    if not isinstance(name, str) or not name.strip() or not isinstance(rect, list) or len(rect) != 4:
        raise ValueError(f"{group} entries need a name and [x, y, width, height] rect")
    if any(type(value) is not int for value in rect):
        raise ValueError(f"{group} rect coordinates must be integers")
    x, y, rect_width, rect_height = rect
    if x < 0 or y < 0 or rect_width <= 0 or rect_height <= 0 or x + rect_width > width or y + rect_height > height:
        raise ValueError(f"{group} rect must be positive and within image bounds")
    return name, (x, y, rect_width, rect_height)


def _subtract(intervals, start, end):
    remaining = []
    for left, right in intervals:
        if end <= left or start >= right:
            remaining.append((left, right))
        else:
            if left < start:
                remaining.append((left, start))
            if end < right:
                remaining.append((end, right))
    return remaining


def compare_png_regions(reference_path, actual_path, regions, ignore_regions=(), channel_threshold=20):
    width, height, reference = _decode_png(reference_path)
    actual_width, actual_height, actual = _decode_png(actual_path)
    if (width, height) != (actual_width, actual_height):
        raise ValueError(f"images must have the same dimensions: {(width, height)} vs {(actual_width, actual_height)}")
    if type(channel_threshold) is not int or not 0 <= channel_threshold <= 255:
        raise ValueError("channel_threshold must be an integer between 0 and 255")
    if not regions:
        raise ValueError("at least one meaningful review region is required")

    parsed_regions = [_rect(entry, width, height, "region") for entry in regions]
    parsed_ignores = [_rect(entry, width, height, "ignore region") for entry in ignore_regions]
    names = [name for name, _ in parsed_regions]
    if len(names) != len(set(names)):
        raise ValueError("region names must be unique")
    ignore_names = [name for name, _ in parsed_ignores]
    if len(ignore_names) != len(set(ignore_names)):
        raise ValueError("ignore region names must be unique")

    results = {}
    for name, (x, y, region_width, region_height) in parsed_regions:
        selected_pixels = region_width * region_height
        compared_pixels = 0
        changed_pixels = 0
        absolute_sum = 0
        for row_y in range(y, y + region_height):
            intervals = [(x, x + region_width)]
            for _, (ignore_x, ignore_y, ignore_width, ignore_height) in parsed_ignores:
                if ignore_y <= row_y < ignore_y + ignore_height:
                    intervals = _subtract(intervals, ignore_x, ignore_x + ignore_width)
            for left, right in intervals:
                for column_x in range(left, right):
                    offset = (row_y * width + column_x) * 3
                    red = abs(reference[offset] - actual[offset])
                    green = abs(reference[offset + 1] - actual[offset + 1])
                    blue = abs(reference[offset + 2] - actual[offset + 2])
                    absolute_sum += red + green + blue
                    changed_pixels += max(red, green, blue) > channel_threshold
                    compared_pixels += 1
        if not compared_pixels:
            raise ValueError(f"region {name!r} contains no pixels after ignored regions")
        results[name] = {
            "selectedPixels": selected_pixels,
            "ignoredPixels": selected_pixels - compared_pixels,
            "comparedPixels": compared_pixels,
            "meanAbsoluteRgbChange": round(absolute_sum / (compared_pixels * 3), 3),
            "pixelsChangedOverThreshold": changed_pixels,
            "pixelsChangedOverThresholdPercent": round(changed_pixels * 100 / compared_pixels, 3),
        }

    return {
        "schemaVersion": 1,
        "status": "REVIEW_ONLY_NO_APPROVED_GOLDEN",
        "channelThreshold": channel_threshold,
        "dimensions": [width, height],
        "regions": results,
    }


def _sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, help="JSON config with before/after paths and named regions")
    parser.add_argument("--report", required=True, help="write the review-only metrics JSON to this path")
    args = parser.parse_args(argv)
    config_path = Path(args.config).resolve()
    config = json.loads(config_path.read_text(encoding="utf-8"))
    base = config_path.parent
    reference = (base / config["reference"]).resolve()
    actual = (base / config["actual"]).resolve()
    report = compare_png_regions(reference, actual, config.get("regions", []), config.get("ignoreRegions", []),
                                 config.get("channelThreshold", 20))
    report["inputs"] = {
        "reference": str(reference),
        "referenceSha256": _sha256(reference),
        "actual": str(actual),
        "actualSha256": _sha256(actual),
    }
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
