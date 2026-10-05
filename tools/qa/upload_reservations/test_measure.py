import unittest
from .measure import validate, parse_metrics


class MeasurementTests(unittest.TestCase):
    def test_idle_or_missing_release_cannot_pass(self):
        for reserved in ([0, 0, 0], [0, 25000000, 25000000]):
            samples = [dict(available=8*1024**3, total=8*1024**3,
                            metric_available=8*1024**3, metric_total=8*1024**3,
                            reserved=value, snapshot_success=1, build_running=True) for value in reserved]
            with self.assertRaises(AssertionError):
                validate(samples, False)

    def test_active_then_released_with_build_and_real_headroom(self):
        samples = [dict(available=8*1024**3, total=8*1024**3,
                        metric_available=8*1024**3, metric_total=8*1024**3,
                        reserved=value, snapshot_success=1, build_running=True)
                   for value in (0, 50000000, 50000000, 25000000, 0)]
        validate(samples, False)
        samples[2]['metric_total'] -= 1
        with self.assertRaises(AssertionError):
            validate(samples, False)

    def test_missing_or_duplicate_metrics_rejected(self):
        for source in ('', 'voice_platform_attachment_upload_reserved_bytes 0\n'*2):
            with self.assertRaises(AssertionError):
                parse_metrics(source)
