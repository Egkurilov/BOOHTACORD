import tempfile
import unittest
from pathlib import Path
from .report import render


class ReportTests(unittest.TestCase):
    def test_missing_or_null_resources_render_as_not_run(self):
        for resources in ('missing', None):
            with self.subTest(resources=resources), tempfile.TemporaryDirectory() as directory:
                driver = dict(Routes={}, Criteria={})
                if resources is None:
                    driver['Resources'] = None
                render(Path(directory), dict(driver=driver))
                page = (Path(directory)/'report.html').read_text()
                for label in ('API CPU % of host', 'API RSS MiB', 'Attachment free MiB'):
                    self.assertIn(label+': NOT_RUN', page)

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
