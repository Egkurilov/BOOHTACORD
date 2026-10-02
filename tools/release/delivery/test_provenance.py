import unittest
from .provenance import validate


class ArtifactProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.run = {'head_sha': 'a' * 40, 'head_repository': {'full_name': 'owner/repo'},
                    'path': '.github/workflows/build-server.yaml', 'head_branch': 'master',
                    'event': 'push', 'status': 'completed', 'conclusion': 'success'}

    def test_successful_master_build(self):
        self.assertEqual(validate(self.run, 'owner/repo'), 'a' * 40)

    def test_pr_fork_wrong_producer_or_failed_run_cannot_become_a_release(self):
        for key, value in (('event', 'pull_request'), ('head_branch', 'codex/change'),
                           ('path', '.github/workflows/ci.yaml'), ('status', 'in_progress'),
                           ('conclusion', 'failure'), ('head_repository', {'full_name': 'fork/repo'})):
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate({**self.run, key: value}, 'owner/repo')
        with self.assertRaises(ValueError): validate(self.run, 'owner/repo', 'b' * 40)
