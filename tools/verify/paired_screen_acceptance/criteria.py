"""Load and verify the acceptance criteria owned by #157."""

import hashlib
import json
import math
from pathlib import Path
from typing import Any

from tools.verify.paired_screen_acceptance.matrix import MOTION_60_CASES, SWITCH_CASES

ROOT = Path(__file__).resolve().parents[3]
CRITERIA_PATH = ROOT / "contracts/screen-share-profile-v1.catalog.json"


def criteria_hash(criteria: dict[str, Any]) -> str:
    canonical = json.dumps(criteria, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def load_quality_acceptance() -> tuple[dict[str, Any], str]:
    catalog = json.loads(CRITERIA_PATH.read_text(encoding="utf-8"))
    criteria = catalog["qualityAcceptance"]
    return criteria, criteria_hash(criteria)


def validate_criteria(criteria: Any) -> list[str]:
    required = {
        "status", "warmupSeconds", "durationSeconds", "windowSeconds", "repeats",
        "minimumValidWindowsPerRun", "presentedFpsP05", "latencyP95Ms",
        "minimumFirstFrameSamplesPerRun", "minimumSwitchSamplesPerRun", "freezeThresholdMs",
    }
    if not isinstance(criteria, dict) or not required.issubset(criteria):
        return ["#157 qualityAcceptance criteria are incomplete"]
    if criteria["status"] not in {"proposed-unvalidated", "approved"}:
        return ["#157 qualityAcceptance status is not recognized"]
    if criteria["status"] == "approved" and not str(criteria.get("approvalReference", "")).strip():
        return ["approved #157 criteria require an approval reference"]
    numeric = required - {"status", "latencyP95Ms"}
    if any(type(criteria[k]) not in (int, float) or not math.isfinite(criteria[k]) or criteria[k] <= 0 for k in numeric):
        return ["#157 qualityAcceptance numeric criteria must be positive"]
    latency = criteria["latencyP95Ms"]
    if not isinstance(latency, dict) or set(latency) != {"firstFrame", "profileSwitch"} or any(type(v) not in (int, float) or v <= 0 for v in latency.values()):
        return ["#157 latency p95 criteria are invalid"]
    return []


def validate_run_thresholds(runs: list[dict[str, Any]], criteria: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    for run in runs:
        case, m = run["caseId"], run["measurements"]
        if run["confidenceMethod"] != "bootstrap-one-sided-95":
            failures.append(f"{case}: #157 one-sided 95% bootstrap bound is missing")
        for field, expected in (("warmupSeconds", criteria["warmupSeconds"]), ("measurementSeconds", criteria["durationSeconds"]), ("windowSeconds", criteria["windowSeconds"])):
            if run[field] != expected:
                failures.append(f"{case}: {field} does not match #157")
        if m["validForegroundWindows"] < criteria["minimumValidWindowsPerRun"]:
            failures.append(f"{case}: valid foreground windows are below #157 minimum")
        if m["firstFrameSampleCount"] < criteria["minimumFirstFrameSamplesPerRun"]:
            failures.append(f"{case}: first-frame sample count is below #157 minimum")
        if m["firstFrameP95Upper95Ms"] > criteria["latencyP95Ms"]["firstFrame"]:
            failures.append(f"{case}: first-frame p95 confidence bound exceeds #157")
        if m["maxPresentationGapMs"] > criteria["freezeThresholdMs"]:
            failures.append(f"{case}: unexplained presentation freeze exceeds #157")
        if case in MOTION_60_CASES and m["presentedFpsP05Lower95"] < criteria["presentedFpsP05"]:
            failures.append(f"{case}: presented FPS lower confidence bound is below #157")
        if case in SWITCH_CASES:
            if m["profileSwitchSampleCount"] < criteria["minimumSwitchSamplesPerRun"]:
                failures.append(f"{case}: profile-switch sample count is below #157 minimum")
            if m["profileSwitchP95Upper95Ms"] > criteria["latencyP95Ms"]["profileSwitch"]:
                failures.append(f"{case}: profile-switch p95 confidence bound exceeds #157")
            if case == "lifecycle-100-switches" and m["profileSwitchAttempts"] < 100:
                failures.append(f"{case}: fewer than 100 profile switches were measured")
    return failures
