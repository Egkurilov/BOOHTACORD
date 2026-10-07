"""Reviewed LiveKit v1.13.7 metric labels after Prometheus relabeling."""
import re

PINNED_LIVEKIT_IMAGE = "livekit/livekit-server:v1.13.7"
BOUNDED_LABELS = frozenset({"node_type", "kind", "direction", "transmission", "source", "type", "le"})
SAFE_METRICS = (
    "livekit_(room_total|participant_total|connection_total|packet_total|packet_bytes|packet_loss_total|"
    "packet_loss_percent_(bucket|sum|count)|packet_out_of_order_total|"
    "packet_out_of_order_percent_(bucket|sum|count)|jitter_us_(bucket|sum|count)|"
    "rtt_ms_(bucket|sum|count))"
)
METRIC_LABELS = {
    "livekit_room_total": {"node_type"},
    "livekit_participant_total": {"node_type"},
    "livekit_connection_total": {"node_type", "kind"},
    "livekit_packet_total": {"node_type", "direction", "transmission"},
    "livekit_packet_bytes": {"node_type", "direction", "transmission"},
    "livekit_packet_loss_total": {"node_type", "direction", "source", "type"},
    "livekit_packet_loss_percent_bucket": {"node_type", "direction", "source", "type", "le"},
    "livekit_packet_loss_percent_sum": {"node_type", "direction", "source", "type"},
    "livekit_packet_loss_percent_count": {"node_type", "direction", "source", "type"},
    "livekit_packet_out_of_order_total": {"node_type", "direction", "source", "type"},
    "livekit_packet_out_of_order_percent_bucket": {"node_type", "direction", "source", "type", "le"},
    "livekit_packet_out_of_order_percent_sum": {"node_type", "direction", "source", "type"},
    "livekit_packet_out_of_order_percent_count": {"node_type", "direction", "source", "type"},
    "livekit_jitter_us_bucket": {"node_type", "direction", "source", "type", "le"},
    "livekit_jitter_us_sum": {"node_type", "direction", "source", "type"},
    "livekit_jitter_us_count": {"node_type", "direction", "source", "type"},
    "livekit_rtt_ms_bucket": {"node_type", "direction", "source", "type", "le"},
    "livekit_rtt_ms_sum": {"node_type", "direction", "source", "type"},
    "livekit_rtt_ms_count": {"node_type", "direction", "source", "type"},
}


def validate_metric_contract(job, image):
    if image != PINNED_LIVEKIT_IMAGE:
        raise ValueError("metric label contract requires the reviewed LiveKit image pin")
    if job.get("relabel_configs") != [
            {"target_label": "instance", "replacement": "boohtacord-livekit-sfu"}]:
        raise ValueError("scraped series must use a fixed instance label")
    filters = job.get("metric_relabel_configs", [])
    expected = [
        {"source_labels": ["__name__"], "regex": SAFE_METRICS, "action": "keep"},
        {"regex": "node_id|country", "action": "labeldrop"},
    ]
    if len(filters) < 2 or filters[0] != expected[0]:
        raise ValueError("LiveKit metric family allowlist is missing")
    dropped = {label for item in filters if item.get("action") == "labeldrop"
               for label in item.get("regex", "").split("|")}
    if not {"node_id", "country"}.issubset(dropped):
        raise ValueError("node_id and country labels must be dropped")
    if filters != expected:
        raise ValueError("LiveKit metric relabeling must remain the reviewed allowlist")
    if {name for name in METRIC_LABELS if re.fullmatch(SAFE_METRICS, name)} != set(METRIC_LABELS):
        raise ValueError("pinned LiveKit metric names do not match their label contract")
    if not METRIC_LABELS or any(not labels <= BOUNDED_LABELS for labels in METRIC_LABELS.values()):
        raise ValueError("pinned LiveKit metrics include an incomplete or non-bounded label contract")
