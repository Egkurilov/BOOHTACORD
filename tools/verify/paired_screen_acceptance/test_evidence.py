import unittest

from tools.verify.paired_screen_acceptance.criteria import criteria_hash, load_quality_acceptance
from tools.verify.paired_screen_acceptance.matrix import METRICS
from tools.verify.paired_screen_acceptance.rules import validate_evidence
def evidence():
    criteria, digest = load_quality_acceptance()
    return {
        "schemaVersion": 1,
        "issue": 173,
        "candidateSha": "NOT_RUN",
        "livekitServerImageDigest": "NOT_RUN",
        "criteriaSha256": digest,
        "status": "NOT_RUN",
        "pairings": [
            {"id": pairing, "result": "NOT_RUN", "unsupportedContractRef": None, "unsupportedCases": {}, "runs": []}
            for pairing in (
                "win-chromium-to-win-chromium", "win-chromium-to-macos-chromium",
                "macos-chromium-to-win-chromium", "chromium-to-safari",
                "flutter-win-to-web", "flutter-macos-to-web", "web-to-flutter-win",
                "web-to-flutter-macos", "android-physical-to-macos",
                "android-physical-to-web", "web-to-android-physical", "web-to-ios",
            )
        ],
    }


def validate(report, criteria=None):
    source, _ = load_quality_acceptance()
    selected = criteria or source
    report["criteriaSha256"] = criteria_hash(selected)
    return validate_evidence(report, selected, criteria_hash(selected))


def measured_run(case_id, repeat):
    return {
        "caseId": case_id, "repeat": repeat, "senderBuild": "1.0.0+1", "receiverBuild": "1.0.0+1",
        "senderOS": "Windows 11", "receiverOS": "macOS 15", "senderDeviceClass": "desktop",
        "receiverDeviceClass": "desktop", "senderGpuDriver": "GPU-driver-x", "receiverGpuDriver": "GPU-driver-y",
        "senderPowerMode": "AC", "receiverPowerMode": "AC", "senderDisplayRefreshHz": 60,
        "receiverDisplayRefreshHz": 60, "warmupSeconds": 30, "measurementSeconds": 180,
        "windowSeconds": 1, "confidenceMethod": "bootstrap-one-sided-95", "profile": case_id,
        "sourceMode": "numbered-motion",
        "captureMode": "full-display", "codec": "VP8", "layerTopology": "single-layer",
        "measurements": {name: 1 for name in METRICS},
    }

class PairedAcceptanceEvidenceTests(unittest.TestCase):
    def test_unrun_template_is_valid_but_does_not_pass(self):
        self.assertEqual([], validate(evidence()))

    def test_pass_requires_five_measured_repeats_per_pairing(self):
        report = evidence()
        report["status"] = "PASS"
        for pairing in report["pairings"]:
            pairing["result"] = "PASS"
        self.assertIn("PASS requires 5 complete repeats for every matrix case", validate(report))

    def test_unsupported_pairing_requires_contract_reference(self):
        report = evidence()
        report["pairings"][0]["result"] = "UNSUPPORTED"
        self.assertIn("unsupported pairing requires a contract reference", validate(report))

    def test_unapproved_fields_are_rejected_to_limit_private_data(self):
        report = evidence()
        report["pairings"][0]["roomName"] = "private-room"
        self.assertIn("pairing contains unapproved fields", validate(report))

    def test_pass_requires_a_real_source_revision(self):
        report = evidence()
        report["status"] = "PASS"
        report["candidateSha"] = "not-a-commit"
        for pairing in report["pairings"]:
            pairing["result"] = "UNSUPPORTED"
            pairing["unsupportedContractRef"] = "contracts/platform-capabilities.md"
        self.assertIn("aggregate PASS requires a 40- or 64-character source SHA", validate(report))
    def test_pass_is_blocked_while_issue_157_thresholds_are_unapproved(self):
        report = evidence()
        report["status"] = "PASS"
        for pairing in report["pairings"]:
            pairing["result"] = "UNSUPPORTED"
            pairing["unsupportedContractRef"] = "contracts/platform-capabilities.md"
        self.assertIn("aggregate PASS is blocked: #157 criteria remain proposed-unvalidated", validate(report))
    def test_complete_matrix_can_be_recorded_as_pass(self):
        report = evidence()
        criteria, _ = load_quality_acceptance()
        criteria["status"] = "approved"
        criteria["approvalReference"] = "test-only simulated owner approval"
        report["candidateSha"] = "a" * 40
        report["livekitServerImageDigest"] = "sha256:" + "b" * 64
        report["status"] = "PASS"
        case_ids = """motion-720p30 motion-720p60 motion-1080p30 motion-1080p60 text-15fps
        text-rate-transition game-video fine-text-scroll capture-full-display capture-window
        capture-tab lifecycle-100-switches voice-screen-audio degraded-network""".split()
        for pairing in report["pairings"]:
            pairing["result"] = "PASS"
            pairing["runs"] = [measured_run(case, repeat) for case in case_ids for repeat in range(1, 6)]
            for run in pairing["runs"]:
                run["measurements"].update(
                    captureWidth=1920, captureHeight=1080, presentedFps=60,
                    presentedFpsP05Lower95=60, maxPresentationGapMs=400,
                    firstFrameP95Upper95Ms=1500, profileSwitchP95Upper95Ms=1500,
                    firstFrameSampleCount=20, profileSwitchSampleCount=20,
                    profileSwitchAttempts=100, validForegroundWindows=180,
                    firstFrameTimeoutCount=0, profileSwitchTimeoutCount=0,
                    freezeCount=0, freezeDurationMs=0,
                )
        self.assertEqual([], validate(report, criteria))
        motion = next(r for r in report["pairings"][0]["runs"] if r["caseId"] == "motion-720p60")
        motion["measurements"]["presentedFpsP05Lower95"] = 54
        errors = validate(report, criteria)
        self.assertTrue(any("presented FPS lower confidence bound" in error for error in errors), errors)
        motion["measurements"]["presentedFpsP05Lower95"] = 60
        report["pairings"][0]["runs"][0]["measurements"]["maxPresentationGapMs"] = 501
        self.assertTrue(any("presentation freeze exceeds #157" in error for error in validate(report, criteria)))


if __name__ == "__main__":
    unittest.main()
