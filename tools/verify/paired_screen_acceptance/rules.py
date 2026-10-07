"""Pure validation rules for the paired screen-share acceptance record."""

import re
from typing import Any

from tools.verify.paired_screen_acceptance.criteria import criteria_hash, validate_criteria, validate_run_thresholds
from tools.verify.paired_screen_acceptance.matrix import (
    PAIRINGS, STATUSES, TOP_FIELDS,
)
from tools.verify.paired_screen_acceptance.pairing_rules import validate_pairing


def validate_evidence(value: Any, criteria: Any, source_hash: str) -> list[str]:
    if not isinstance(value, dict) or set(value) != TOP_FIELDS: return ["evidence must contain only the approved top-level fields"]
    errors = validate_criteria(criteria)
    if criteria_hash(criteria) != source_hash or value["criteriaSha256"] != source_hash:
        errors.append("evidence criteria hash does not match the #157 catalog source")
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
        errors.extend(validate_pairing(pairing, criteria["repeats"]))
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
        if criteria.get("status") != "approved":
            errors.append("aggregate PASS is blocked: #157 criteria remain proposed-unvalidated")
        elif not errors:
            errors.extend(validate_run_thresholds([r for p in pairings for r in p["runs"]], criteria))
    return errors
