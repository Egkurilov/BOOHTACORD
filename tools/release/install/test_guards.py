import unittest
from .guards import disk_budget, installed_digests, writer_topology


class InstallGuardsTests(unittest.TestCase):
    def test_writer_preflight_rejects_multiple_and_start_first(self):
        writer_topology({'services': {'api': {}}}, '')
        with self.assertRaises(ValueError):
            writer_topology({'services': {'api': {'scale': 2}}}, '')
        supported = {'replicas': 1, 'update_config': {'order': 'stop-first'}, 'rollback_config': {'order': 'stop-first'}}
        writer_topology({'services': {'api': {'deploy': supported}}}, 'one')
        for deployment, running in (({**supported, 'replicas': 2}, 'one'),
                                    ({**supported, 'update_config': {'order': 'start-first'}}, 'one'),
                                    ({**supported, 'rollback_config': {'order': 'start-first'}}, 'one'),
                                    (supported, 'one\ntwo')):
            with self.assertRaises(ValueError):
                writer_topology({'services': {'api': {'deploy': deployment}}}, running)

    def test_disk_budget_accounts_for_payload_and_protected_space(self):
        disk_budget(10_000_000_000, 100_000_000)
        for available, payload in ((1_000_000, 100_000_000), (5_000_000_000, 2_000_000_000), (10_000_000_000, 0)):
            with self.assertRaises(ValueError): disk_budget(available, payload)

    def test_running_digest_and_reference_must_match_verified_release(self):
        expected = "sha256:" + "a" * 64
        reference = "voice-platform-api@" + expected
        installed_digests(expected, expected, expected, reference, "api")
        for loaded, running, configured in (("sha256:" + "b" * 64, expected, reference),
                                            (expected, "sha256:" + "b" * 64, reference),
                                            (expected, expected, "voice-platform-api:latest")):
            with self.assertRaises(ValueError): installed_digests(expected, loaded, running, configured, "api")


if __name__ == "__main__": unittest.main()
