"""Reusable synthetic evidence fixtures for validator tests only."""

from tools.verify.paired_screen_acceptance.criteria import criteria_hash, load_quality_acceptance
from tools.verify.paired_screen_acceptance.matrix import METRICS
from tools.verify.paired_screen_acceptance.rules import validate_evidence

PAIRING_IDS = """win-chromium-to-win-chromium win-chromium-to-macos-chromium
macos-chromium-to-win-chromium chromium-to-safari flutter-win-to-web flutter-macos-to-web
web-to-flutter-win web-to-flutter-macos android-physical-to-macos android-physical-to-web
web-to-android-physical web-to-ios""".split()
CASE_IDS = """motion-720p30 motion-720p60 motion-1080p30 motion-1080p60 text-15fps
text-rate-transition game-video fine-text-scroll capture-full-display capture-window
capture-tab lifecycle-100-switches voice-screen-audio degraded-network""".split()


def evidence():
    _, digest = load_quality_acceptance()
    return {
        "schemaVersion": 1, "issue": 173, "candidateSha": "NOT_RUN",
        "livekitServerImageDigest": "NOT_RUN", "criteriaSha256": digest,
        "status": "NOT_RUN", "pairings": [
            {"id": key, "result": "NOT_RUN", "unsupportedContractRef": None,
             "unsupportedCases": {}, "runs": []} for key in PAIRING_IDS
        ],
    }


def validate(report, criteria=None):
    source, _ = load_quality_acceptance()
    selected = criteria or source
    digest = criteria_hash(selected)
    report["criteriaSha256"] = digest
    return validate_evidence(report, selected, digest)


def measured_run(case_id, repeat):
    return {
        "caseId": case_id, "repeat": repeat, "senderBuild": "1.0.0+1",
        "receiverBuild": "1.0.0+1", "senderOS": "Windows 11", "receiverOS": "macOS 15",
        "senderDeviceClass": "desktop", "receiverDeviceClass": "desktop",
        "senderGpuDriver": "GPU-driver-x", "receiverGpuDriver": "GPU-driver-y",
        "senderPowerMode": "AC", "receiverPowerMode": "AC", "senderDisplayRefreshHz": 60,
        "receiverDisplayRefreshHz": 60, "warmupSeconds": 30, "measurementSeconds": 180,
        "windowSeconds": 1, "confidenceMethod": "bootstrap-one-sided-95", "profile": case_id,
        "sourceMode": "numbered-motion", "captureMode": "full-display", "codec": "VP8",
        "layerTopology": "single-layer", "measurements": {name: 1 for name in METRICS},
    }
