import tempfile
import unittest
from pathlib import Path
from .report import render


class ReportTests(unittest.TestCase):
    def test_graphs_and_csv_keep_units_and_escape_labels(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            report = dict(driver=dict(Routes={'<script>': dict(Count=1, Errors=0, P50MS=1, P95MS=2, P99MS=3)},
                Resources=[dict(CPUPercent=10, RSSBytes=1 << 20, FreeBytes=512 << 20)],
                Criteria={'capacity': 'NOT_RUN'}))
            render(target, report)
            page = (target/'report.html').read_text()
            self.assertNotIn('<script>', page)
            self.assertIn('API RSS MiB', page)
            self.assertIn('last 6000', page)
            self.assertIn('NOT_RUN', page)
            self.assertIn('p95_ms', (target/'routes.csv').read_text())


if __name__ == '__main__':
    unittest.main()
