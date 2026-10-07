"""Fail-closed checks for the repository's LiveKit network topology."""

SAFE_METRICS = (
    "livekit_(room_total|participant_total|connection_total|packet_total|packet_bytes|packet_loss_total|"
    "packet_loss_percent_(bucket|sum|count)|packet_out_of_order_total|"
    "packet_out_of_order_percent_(bucket|sum|count)|jitter_us_(bucket|sum|count)|"
    "rtt_ms_(bucket|sum|count))"
)


def _range(value):
    parts = [int(part) for part in str(value).split("-")]
    if len(parts) not in (1, 2) or not 1 <= parts[0] <= parts[-1] <= 65535:
        raise ValueError("invalid published media port range")
    return parts[0], parts[-1]


def _port_mapping(spec):
    if not isinstance(spec, str):
        raise ValueError("LiveKit published ports must use explicit short syntax")
    address, _, protocol = spec.rpartition("/")
    address = address or spec
    fields = address.split(":")
    if len(fields) < 2:
        raise ValueError("LiveKit ports must map host and container ports")
    return _range(fields[-2]), _range(fields[-1]), protocol or "tcp"


def _network_list(service):
    networks = service.get("networks", [])
    return list(networks) if isinstance(networks, list) else list(networks)


def validate(livekit, deploy, observability_compose, prometheus, alerts):
    rtc = livekit.get("rtc", {})
    start, end = rtc.get("port_range_start"), rtc.get("port_range_end")
    tcp = rtc.get("tcp_port")
    if not (isinstance(start, int) and isinstance(end, int) and 1 <= start <= end <= 65535):
        raise ValueError("invalid configured UDP range")
    if not (isinstance(tcp, int) and 1 <= tcp <= 65535 and rtc.get("use_external_ip") is True):
        raise ValueError("TCP fallback or external IP advertisement is not explicitly configured")

    services = deploy.get("services", {})
    server = services.get("livekit", {})
    mappings = [_port_mapping(port) for port in server.get("ports", [])]
    if not any(protocol == "udp" and host == (start, end) and target == (start, end)
               for host, target, protocol in mappings):
        raise ValueError("UDP range must be published unchanged")
    if not any(protocol == "tcp" and host == (tcp, tcp) and target == (tcp, tcp)
               for host, target, protocol in mappings):
        raise ValueError("TCP fallback port must be published unchanged")
    api_port = livekit.get("port")
    if not isinstance(api_port, int) or any(target[0] <= api_port <= target[1]
                                             for _, target, _ in mappings):
        raise ValueError("LiveKit signaling API port must stay behind the proxy")

    metrics_port = livekit.get("prometheus_port")
    if not (isinstance(metrics_port, int) and 1 <= metrics_port <= 65535):
        raise ValueError("private LiveKit metrics port is not configured")
    if metrics_port == api_port or metrics_port == tcp or start <= metrics_port <= end:
        raise ValueError("LiveKit metrics port conflicts with a media or signaling port")
    if any(target[0] <= metrics_port <= target[1] for _, target, _ in mappings):
        raise ValueError("LiveKit metrics port must not publish to the host")

    network_name = "livekit-metrics"
    network = deploy.get("networks", {}).get(network_name, {})
    if network.get("internal") is not True or network_name not in _network_list(server):
        raise ValueError("LiveKit metrics must use an internal dedicated network")
    for name, service in services.items():
        if name != "livekit" and network_name in _network_list(service):
            raise ValueError("only LiveKit may join the dedicated metrics network")
    if deploy.get("name") != "voice-platform":
        raise ValueError("metrics network identity must stay stable")

    observer_network = observability_compose.get("networks", {}).get(network_name, {})
    if observer_network.get("external") is not True or observer_network.get("name") != (
            "voice-platform_livekit-metrics"):
        raise ValueError("Prometheus must attach to the dedicated private network")
    if network_name not in _network_list(observability_compose.get("services", {}).get("prometheus", {})):
        raise ValueError("Prometheus is not attached to the private metrics network")

    jobs = [job for job in prometheus.get("scrape_configs", [])
            if job.get("job_name") == "boohtacord-livekit"]
    target = f"livekit:{metrics_port}"
    if len(jobs) != 1 or jobs[0].get("metrics_path") != "/metrics" or jobs[0].get(
            "static_configs", [{}])[0].get("targets") != [target]:
        raise ValueError("LiveKit scrape must use its private service target")
    job = jobs[0]
    if not any(item.get("target_label") == "instance" and item.get("replacement") ==
               "boohtacord-livekit-sfu" for item in job.get("relabel_configs", [])):
        raise ValueError("scraped series must use a fixed instance label")
    filters = job.get("metric_relabel_configs", [])
    if not any(item.get("action") == "keep" and item.get("source_labels") == ["__name__"]
               and item.get("regex") == SAFE_METRICS for item in filters):
        raise ValueError("LiveKit metric family allowlist is missing")
    dropped = {label for item in filters if item.get("action") == "labeldrop"
               for label in item.get("regex", "").split("|")}
    if not {"node_id", "country"}.issubset(dropped):
        raise ValueError("node_id and country labels must be dropped")

    rules = [rule for group in alerts.get("groups", []) for rule in group.get("rules", [])]
    if not any(rule.get("alert") == "LiveKitMetricsScrapeUnavailable" and
               rule.get("expr") == 'up{job="boohtacord-livekit"} == 0' and
               rule.get("for") == "2m" for rule in rules):
        raise ValueError("LiveKit scrape availability alert is missing")
