"""Pure validation rules for the paired screen-share acceptance record."""

import math
import re
from typing import Any

from tools.verify.paired_screen_acceptance.matrix import (
    CASE_IDS, METRICS, NUMERIC_ENVIRONMENT, PAIR_FIELDS, PAIRINGS, PASS_METRICS,
    RUN_FIELDS, STATUSES, TOP_FIELDS,
)

def validate_evidence(value: Any) -> list[str]:
    if not isinstance(value, dict) or set(value) != TOP_FIELDS: return ["evidence must contain only the approved top-level fields"]
    errors: list[str] = []
    if value["schemaVersion"] != 1 or value["issue"] != 173:
        errors.append("schemaVersion must be 1 and issue must be 173")
    if not isinstance(value["status"], str) or value["status"] not in STATUSES:
        errors.append("invalid aggregate status")
    if not isinstance(value["candidateSha"], str):
        errors.append("candidateSha must be a string")
    pairings = value["pairings"]
    if not isinstance(pairings, list): return errors + ["pairings must be a list"]
    ids = [p.get("id") for p in pairings if isinstance(p, dict)]
    if len(ids) != len(pairings) or not all(isinstance(i, str) for i in ids) or set(ids) != PAIRINGS or len(ids) != len(PAIRINGS):
        return errors + ["pairings must contain each required direction exactly once"]
    for pairing in pairings:
        errors.extend(_validate_pairing(pairing))
    if value["status"] == "PASS" and not errors:
        if any(p["result"] not in {"PASS", "UNSUPPORTED"} for p in pairings):
            errors.append("aggregate PASS requires all pairings to pass or be contractually unsupported")
        if not any(p["result"] == "PASS" for p in pairings):
            errors.append("aggregate PASS requires at least one measured supported pairing")
        sha = value["candidateSha"]
        if not isinstance(sha, str) or not re.fullmatch(r"[0-9a-fA-F]{40}|[0-9a-fA-F]{64}", sha):
            errors.append("aggregate PASS requires a 40- or 64-character source SHA")
        image = value["livekitServerImageDigest"]
        if not isinstance(image, str) or not re.fullmatch(r"sha256:[0-9a-fA-F]{64}", image):
            errors.append("aggregate PASS requires the tested LiveKit image digest")
    return errors

def _validate_pairing(pairing: dict[str, Any]) -> list[str]:
    if set(pairing) != PAIR_FIELDS:
        return ["pairing contains unapproved fields"]
    result, runs, ref = pairing["result"], pairing["runs"], pairing["unsupportedContractRef"]
    unsupported = pairing["unsupportedCases"]
    if not isinstance(result, str) or result not in STATUSES or not isinstance(runs, list): return ["pairing has an invalid result or runs list"]
    if not isinstance(unsupported, dict) or any(not isinstance(k, str) or k not in CASE_IDS for k in unsupported):
        return ["unsupportedCases must map approved case IDs to contract references"]
    errors: list[str] = []
    if any(not isinstance(v, str) or not v.strip() for v in unsupported.values()):
        errors.append("each unsupported case requires a contract reference")
    if result == "UNSUPPORTED" and not (isinstance(ref, str) and ref.strip()):
        errors.append("unsupported pairing requires a contract reference")
    if result != "UNSUPPORTED" and ref is not None:
        errors.append("contract reference is only allowed for unsupported pairings")
    if result == "NOT_RUN" and (runs or unsupported):
        errors.append("NOT_RUN pairing cannot contain observed runs or classifications")
    for run in runs:
        errors.extend(_validate_run(run))
    if result == "PASS" and not errors and not _has_complete_repeats(runs, unsupported):
        errors.append("PASS requires three complete runs for every matrix case")
    if result == "PASS" and not errors:
        missing = any(r["measurements"][k] is None for r in runs for k in (METRICS if r["caseId"] == "lifecycle-100-switches" else PASS_METRICS))
        if missing:
            errors.append("PASS requires measured metrics; unavailable values remain null")
    if result == "UNSUPPORTED" and runs:
        errors.append("an unsupported direction cannot contain measured runs")
    return errors

def _validate_run(run: Any) -> list[str]:
    if not isinstance(run, dict) or set(run) != RUN_FIELDS: return ["run contains missing or unapproved fields"]
    metrics = run["measurements"]
    if not isinstance(metrics, dict) or set(metrics) != METRICS:
        return ["run must include the fixed metric set; unknown values stay null"]
    if any(v is not None and (type(v) not in (int, float) or not math.isfinite(v) or v < 0) for v in metrics.values()):
        return ["measurements must be finite non-negative numbers or null"]
    if metrics["packetLossPercent"] is not None and metrics["packetLossPercent"] > 100:
        return ["packet loss percentage cannot exceed 100"]
    text_fields = RUN_FIELDS - {"repeat", "measurements"} - NUMERIC_ENVIRONMENT
    if any(not isinstance(run[k], str) or not run[k].strip() or len(run[k]) > 100 for k in text_fields):
        return ["run metadata must be non-empty bounded text"]
    if any(type(run[k]) not in (int, float) or not math.isfinite(run[k]) or run[k] <= 0 for k in NUMERIC_ENVIRONMENT):
        return ["sender and receiver display refresh rates must be positive numbers"]
    if any(type(metrics[k]) is not int or metrics[k] < 2 for k in ("captureWidth", "captureHeight")):
        return ["actual capture dimensions are required; unknown metrics stay null"]
    if run["caseId"] in {"motion-720p60", "motion-1080p60"} and min(run[k] for k in NUMERIC_ENVIRONMENT) < 60:
        return ["60 FPS cases require both displays to refresh at 60 Hz or above"]
    if not isinstance(run["repeat"], int) or isinstance(run["repeat"], bool) or run["repeat"] not in (1, 2, 3):
        return ["repeat must be 1, 2, or 3"]
    if run["caseId"] not in CASE_IDS:
        return ["run caseId is not in the approved matrix"]
    return []

def _has_complete_repeats(runs: list[dict[str, Any]], unsupported: dict[str, str]) -> bool:
    counts = {case: [r["repeat"] for r in runs if r["caseId"] == case] for case in CASE_IDS - set(unsupported)}
    return bool(counts) and set(counts) | set(unsupported) == CASE_IDS and all(sorted(v) == [1, 2, 3] for v in counts.values())
