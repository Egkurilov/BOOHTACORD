import unittest

from tools.verify.paired_screen_acceptance.validate_evidence import validate_evidence


def evidence():
    return {
        "schemaVersion": 1,
        "issue": 173,
        "candidateSha": "NOT_RUN",
        "livekitServerImageDigest": "NOT_RUN",
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


def measured_run(case_id, repeat):
    metric_names = """sourceFps captureWidth captureHeight encodedFps decodedFps presentedFps uniqueFrameDelta
    duplicateFrames skippedFrames freezeCount freezeDurationMs firstFrameP95Ms switchP95Ms
    encodeTimeP95Ms decodeTimeP95Ms packetLossPercent rttP95Ms jitterP95Ms""".split()
    return {
        "caseId": case_id, "repeat": repeat, "senderBuild": "1.0.0+1", "receiverBuild": "1.0.0+1",
        "senderOS": "Windows 11", "receiverOS": "macOS 15", "senderDeviceClass": "desktop",
        "receiverDeviceClass": "desktop", "senderGpuDriver": "GPU-driver-x", "receiverGpuDriver": "GPU-driver-y",
        "senderPowerMode": "AC", "receiverPowerMode": "AC", "senderDisplayRefreshHz": 60,
        "receiverDisplayRefreshHz": 60, "profile": case_id, "sourceMode": "numbered-motion",
        "captureMode": "full-display", "codec": "VP8", "layerTopology": "single-layer",
        "measurements": {name: 1 for name in metric_names},
    }


class PairedAcceptanceEvidenceTests(unittest.TestCase):
    def test_unrun_template_is_valid_but_does_not_pass(self):
        self.assertEqual([], validate_evidence(evidence()))

    def test_pass_requires_three_measured_repeats_per_pairing(self):
        report = evidence()
        report["status"] = "PASS"
        for pairing in report["pairings"]:
            pairing["result"] = "PASS"
        self.assertIn("PASS requires three complete runs for every matrix case", validate_evidence(report))

    def test_unsupported_pairing_requires_contract_reference(self):
        report = evidence()
        report["pairings"][0]["result"] = "UNSUPPORTED"
        self.assertIn("unsupported pairing requires a contract reference", validate_evidence(report))

    def test_unapproved_fields_are_rejected_to_limit_private_data(self):
        report = evidence()
        report["pairings"][0]["roomName"] = "private-room"
        self.assertIn("pairing contains unapproved fields", validate_evidence(report))

    def test_pass_requires_a_real_source_revision(self):
        report = evidence()
        report["status"] = "PASS"
        report["candidateSha"] = "not-a-commit"
        for pairing in report["pairings"]:
            pairing["result"] = "UNSUPPORTED"
            pairing["unsupportedContractRef"] = "contracts/platform-capabilities.md"
        self.assertIn("aggregate PASS requires a 40- or 64-character source SHA", validate_evidence(report))

    def test_complete_matrix_can_be_recorded_as_pass(self):
        report = evidence()
        report["candidateSha"] = "a" * 40
        report["livekitServerImageDigest"] = "sha256:" + "b" * 64
        report["status"] = "PASS"
        case_ids = """motion-720p30 motion-720p60 motion-1080p30 motion-1080p60 text-15fps
        text-rate-transition game-video fine-text-scroll capture-full-display capture-window
        capture-tab lifecycle-100-switches voice-screen-audio degraded-network""".split()
        for pairing in report["pairings"]:
            pairing["result"] = "PASS"
            pairing["runs"] = [measured_run(case, repeat) for case in case_ids for repeat in (1, 2, 3)]
            for run in pairing["runs"]:
                run["measurements"].update(captureWidth=1920, captureHeight=1080)
        self.assertEqual([], validate_evidence(report))
        report["pairings"][0]["runs"][0]["measurements"]["encodedFps"] = None
        self.assertIn("PASS requires measured metrics; unavailable values remain null", validate_evidence(report))


if __name__ == "__main__":
    unittest.main()
