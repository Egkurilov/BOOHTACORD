import csv
import importlib.util
import itertools
import random
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("blind_trials", Path(__file__).with_name("blind_trials.py"))
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)

class BlindTrialsTest(unittest.TestCase):
    def test_complete_primary_matrix_with_unique_blind_ids(self):
        assignments = driver.trials(rng=random.Random(1))
        self.assertEqual(len(assignments), 144)
        self.assertEqual(len({item["trial"] for item in assignments}), 144)
        actual = {(item["direction"], item["profile"], item["loss_percent"], item["scenario"]) for item in assignments}
        expected = set(itertools.product(driver.DIRECTIONS, ["baseline-128-v1", "speech-64-v1", "speech-96-v1"], driver.LOSS, driver.SCENARIOS))
        self.assertEqual(actual, expected)

    def test_listener_sheet_does_not_reveal_platform_profile_or_dsp(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "blind"
            driver.write_plan(destination, driver.trials(rng=random.Random(2)))
            rows = list(csv.DictReader((destination / "listener.csv").open(encoding="utf-8")))
            self.assertEqual(len(rows), 144)
            text = (destination / "listener.csv").read_text(encoding="utf-8")
            self.assertNotIn("speech-64", text)
            self.assertNotIn("windows", text)
            self.assertNotIn("agc", text)

    def test_mobile_and_dsp_isolation_keep_baseline_until_measurements(self):
        assignments = driver.trials(mobile=True, isolation=True, rng=random.Random(3))
        self.assertEqual({item["profile"] for item in assignments}, {"baseline-128-v1"})
        self.assertEqual(len({(item["agc"], item["aec"], item["ns"]) for item in assignments}), 8)
        self.assertIn("ios-web", {item["direction"] for item in assignments})

    def test_refuses_repository_output(self):
        with self.assertRaises(ValueError):
            driver.write_plan(driver.ROOT / "private-test-output", [])

if __name__ == "__main__":
    unittest.main()
