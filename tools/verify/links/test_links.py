import unittest
from .check import check_links, task_references
from .markdown import targets
from .evidence import references


class LinkTests(unittest.TestCase):
    def test_json_evidence_checks_nested_repo_links_with_line_numbers(self):
        self.assertEqual(list(references({'checks': [{'evidence': 'evidence/run.json'}],
                                        'source': 'backlog/TODO.md:43'})), ['evidence/run.json', 'backlog/TODO.md'])

    def test_external_retained_media_is_not_claimed_to_exist_in_checkout(self):
        self.assertEqual(list(references(['evidence/design/artifacts/picture.png', '/tmp/report.json'])), [])

    def test_relative_inline_and_reference_paths(self):
        self.assertEqual(list(targets('[x](../a.md#title)\n[y]: <a%20b.md>')), ['../a.md', 'a b.md'])

    def test_external_anchors_and_fenced_examples_are_ignored(self):
        text = '[x](https://example.org) [y](#title)\n```md\n[x](absent.md)\n```\n'
        self.assertEqual(list(targets(text)), [])

    def test_missing_path_and_workspace_escape_are_rejected(self):
        self.assertEqual(len(check_links({'README.md': '[x](gone.md) [y](../outside.md)'}, {'README.md'})), 2)

    def test_readme_agents_and_evidence_links_use_the_document_directory(self):
        docs = {'AGENTS.md': '[x](docs/a.md)', 'evidence/run.md': '[code](../tools/run.py)'}
        self.assertEqual(check_links(docs, {'docs/a.md', 'tools/run.py'}), [])

    def test_task_evidence_labels_are_not_paths(self):
        data = {'action_catalog': {'done': 'DONE.md'}, 'tasks': [{'evidence': ['health-smoke', 'evidence/one.json']}]}
        self.assertEqual(list(task_references(data)), ['DONE.md', 'evidence/one.json'])
