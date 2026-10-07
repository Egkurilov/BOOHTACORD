"""Validate one pairing and its measured cases."""

import math
from typing import Any

from tools.verify.paired_screen_acceptance.matrix import (
    CASE_IDS, DISPLAY_REFRESH_FIELDS, DURATION_FIELDS, METRICS, PAIR_FIELDS,
    PASS_METRICS, RUN_FIELDS, STATUSES, SWITCH_CASES,
)


def validate_pairing(pairing: Any, repeat_count: int) -> list[str]:
    if not isinstance(pairing, dict) or set(pairing) != PAIR_FIELDS:
        return ["pairing contains unapproved fields"]
    result, runs, ref = pairing["result"], pairing["runs"], pairing["unsupportedContractRef"]
    unsupported = pairing["unsupportedCases"]
    if result not in STATUSES or not isinstance(runs, list):
        return ["pairing has an invalid result or runs list"]
    if not isinstance(unsupported, dict) or any(k not in CASE_IDS for k in unsupported):
        return ["unsupportedCases must map approved case IDs to contract references"]
    errors = ["each unsupported case requires a contract reference"] if any(not isinstance(v, str) or not v.strip() for v in unsupported.values()) else []
    if result == "UNSUPPORTED" and not (isinstance(ref, str) and ref.strip()):
        errors.append("unsupported pairing requires a contract reference")
    if result != "UNSUPPORTED" and ref is not None:
        errors.append("contract reference is only allowed for unsupported pairings")
    if result == "NOT_RUN" and (runs or unsupported):
        errors.append("NOT_RUN pairing cannot contain observed runs or classifications")
    for run in runs:
        errors.extend(validate_run(run))
    if result == "PASS" and not errors and not complete_repeats(runs, unsupported, repeat_count):
        errors.append(f"PASS requires {repeat_count} complete repeats for every matrix case")
    if result == "PASS" and not errors and any(
        r["measurements"][key] is None for r in runs
        for key in (METRICS if r["caseId"] in SWITCH_CASES else PASS_METRICS)
    ):
        errors.append("PASS requires measured metrics; unavailable values remain null")
    if result == "UNSUPPORTED" and runs:
        errors.append("an unsupported direction cannot contain measured runs")
    return errors


def validate_run(run: Any) -> list[str]:
    if not isinstance(run, dict) or set(run) != RUN_FIELDS:
        return ["run contains missing or unapproved fields"]
    metrics = run["measurements"]
    if not isinstance(metrics, dict) or set(metrics) != METRICS:
        return ["run must include the fixed metric set; unknown values stay null"]
    if any(v is not None and (type(v) not in (int, float) or not math.isfinite(v) or v < 0) for v in metrics.values()):
        return ["measurements must be finite non-negative numbers or null"]
    if metrics["packetLossPercent"] is not None and metrics["packetLossPercent"] > 100:
        return ["packet loss percentage cannot exceed 100"]
    text = RUN_FIELDS - {"repeat", "measurements"} - DISPLAY_REFRESH_FIELDS - DURATION_FIELDS
    if any(not isinstance(run[k], str) or not run[k].strip() or len(run[k]) > 100 for k in text):
        return ["run metadata must be non-empty bounded text"]
    if any(type(run[k]) not in (int, float) or not math.isfinite(run[k]) or run[k] <= 0 for k in DISPLAY_REFRESH_FIELDS | DURATION_FIELDS):
        return ["display refresh rates and measurement durations must be positive numbers"]
    if any(type(metrics[k]) is not int or metrics[k] < 2 for k in ("captureWidth", "captureHeight")):
        return ["actual capture dimensions are required; unknown metrics stay null"]
    if run["caseId"] in {"motion-720p60", "motion-1080p60"} and min(run[k] for k in DISPLAY_REFRESH_FIELDS) < 60:
        return ["60 FPS cases require both displays to refresh at 60 Hz or above"]
    if not isinstance(run["repeat"], int) or isinstance(run["repeat"], bool) or run["repeat"] < 1:
        return ["repeat must be a positive integer"]
    if run["caseId"] not in CASE_IDS:
        return ["run caseId is not in the approved matrix"]
    return []


def complete_repeats(runs: list[dict[str, Any]], unsupported: dict[str, str], repeat_count: int) -> bool:
    counts = {case: [r["repeat"] for r in runs if r["caseId"] == case] for case in CASE_IDS - set(unsupported)}
    expected = list(range(1, repeat_count + 1))
    return bool(counts) and set(counts) | set(unsupported) == CASE_IDS and all(sorted(v) == expected for v in counts.values())
