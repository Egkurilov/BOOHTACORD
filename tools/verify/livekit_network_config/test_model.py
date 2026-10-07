"""Safety and wiring tests for the pinned LiveKit deployment model."""
import unittest

from .fixtures import valid_model
from .model import validate
from .check import main


class LiveKitNetworkConfigTests(unittest.TestCase):
    def setUp(self):
        (self.livekit, self.deploy, self.observability_compose,
         self.prometheus, self.alerts) = valid_model()

    def assert_valid(self):
        validate(self.livekit, self.deploy, self.observability_compose, self.prometheus, self.alerts)

    def test_private_metrics_scrape_and_udp_tcp_publication_are_wired(self):
        self.assert_valid()

    def test_checked_in_compose_and_prometheus_files_match_the_model(self):
        main()

    def test_rejects_missing_udp_range_mapping(self):
        self.deploy["services"]["livekit"]["ports"].pop()
        with self.assertRaisesRegex(ValueError, "UDP range"):
            self.assert_valid()

    def test_rejects_published_metrics_port(self):
        self.deploy["services"]["livekit"]["ports"].append("6789:6789/tcp")
        with self.assertRaisesRegex(ValueError, "must not publish"):
            self.assert_valid()

    def test_rejects_public_signaling_api_port(self):
        self.deploy["services"]["livekit"]["ports"].append("7880:7880/tcp")
        with self.assertRaisesRegex(ValueError, "behind the proxy"):
            self.assert_valid()

    def test_rejects_metrics_network_access_for_api_or_database(self):
        self.deploy["services"]["api"]["networks"].append("livekit-metrics")
        with self.assertRaisesRegex(ValueError, "only LiveKit"):
            self.assert_valid()

    def test_rejects_node_and_country_labels_or_unbounded_metric_families(self):
        relabels = self.prometheus["scrape_configs"][0]["metric_relabel_configs"]
        relabels[1]["regex"] = "country"
        with self.assertRaisesRegex(ValueError, "node_id"):
            self.assert_valid()

        self.prometheus["scrape_configs"][0]["metric_relabel_configs"] = [
            {"source_labels": ["__name__"], "regex": "livekit_.*", "action": "keep"},
            {"regex": "node_id|country", "action": "labeldrop"},
        ]
        with self.assertRaisesRegex(ValueError, "allowlist"):
            self.assert_valid()

    def test_rejects_scrape_target_outside_private_metrics_network(self):
        self.observability_compose["networks"]["livekit-metrics"]["name"] = "public-edge"
        with self.assertRaisesRegex(ValueError, "private network"):
            self.assert_valid()

    def test_rejects_external_ip_advertisement_drift(self):
        self.livekit["rtc"]["use_external_ip"] = False
        with self.assertRaisesRegex(ValueError, "external IP"):
            self.assert_valid()

    def test_rejects_tcp_fallback_mapping_drift(self):
        self.deploy["services"]["livekit"]["ports"][0] = "7881:7881/tcp"
        with self.assertRaisesRegex(ValueError, "TCP fallback"):
            self.assert_valid()


if __name__ == "__main__":
    unittest.main()
