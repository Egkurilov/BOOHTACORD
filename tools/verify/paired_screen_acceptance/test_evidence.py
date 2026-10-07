import unittest

from tools.verify.paired_screen_acceptance.criteria import load_quality_acceptance
from tools.verify.paired_screen_acceptance.test_support import CASE_IDS, evidence, measured_run, validate


class PairedAcceptanceEvidenceTests(unittest.TestCase):
    def test_unrun_template_is_valid(self):
        self.assertEqual([], validate(evidence()))

    def test_pass_requires_five_repeats(self):
        report = evidence()
        report["status"] = "PASS"
        for pair in report["pairings"]:
            pair["result"] = "PASS"
        self.assertIn("PASS requires 5 complete repeats for every matrix case", validate(report))

    def test_unsupported_pairing_requires_contract_reference(self):
        report = evidence()
        report["pairings"][0]["result"] = "UNSUPPORTED"
        self.assertIn("unsupported pairing requires a contract reference", validate(report))

    def test_private_or_unapproved_fields_are_rejected(self):
        report = evidence()
        report["pairings"][0]["roomName"] = "private-room"
        self.assertIn("pairing contains unapproved fields", validate(report))

    def test_pass_requires_a_real_source_revision(self):
        report = evidence()
        report.update(status="PASS", candidateSha="not-a-commit")
        for pair in report["pairings"]:
            pair.update(result="UNSUPPORTED", unsupportedContractRef="contracts/platform-capabilities.md")
        self.assertIn("aggregate PASS requires a 40- or 64-character source SHA", validate(report))

    def test_unapproved_issue_157_criteria_block_pass(self):
        report = evidence()
        report["status"] = "PASS"
        for pair in report["pairings"]:
            pair.update(result="UNSUPPORTED", unsupportedContractRef="contracts/platform-capabilities.md")
        self.assertIn("aggregate PASS is blocked: #157 criteria remain proposed-unvalidated", validate(report))

    def test_approved_thresholds_reject_low_fps_and_freezes(self):
        report = evidence()
        criteria, _ = load_quality_acceptance()
        criteria.update(status="approved", approvalReference="test-only simulated approval")
        report.update(candidateSha="a" * 40, livekitServerImageDigest="sha256:" + "b" * 64, status="PASS")
        for pair in report["pairings"]:
            pair.update(result="PASS", runs=[measured_run(case, repeat) for case in CASE_IDS for repeat in range(1, 6)])
            for run in pair["runs"]:
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
        motion = next(run for run in report["pairings"][0]["runs"] if run["caseId"] == "motion-720p60")
        motion["measurements"]["presentedFpsP05Lower95"] = 54
        self.assertTrue(any("presented FPS lower confidence bound" in error for error in validate(report, criteria)))
        motion["measurements"].update(presentedFpsP05Lower95=60, maxPresentationGapMs=501)
        self.assertTrue(any("presentation freeze exceeds #157" in error for error in validate(report, criteria)))


if __name__ == "__main__":
    unittest.main()
