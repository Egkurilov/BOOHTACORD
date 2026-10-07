# LiveKit network acceptance

Use this runbook with the isolated screen-share baseline in `evidence/screen-share-baseline/verification.md`. It separates repository configuration checks from deployment and media-path acceptance. A working signaling connection does not establish a working media path.

## Repository configuration

- Run `python -m tools.verify.livekit_network_config.check` and both Compose `config --quiet` checks recorded in the evidence file.
- Deploy the application Compose project before the observability project. Prometheus joins only the dedicated internal media-metrics network. The metrics listener has no host port publication.
- The scrape stores an allowlisted set of aggregate LiveKit packet, RTT, jitter, connection, room and participant metrics. It removes the node identifier and country labels and replaces the target instance label with a fixed name.
- Do not infer external TURN availability or production NAT/firewall state from repository templates. Capture image digests and effective configuration only in the approved restricted deployment workflow; publish a redacted pass/fail comparison without raw configuration.

## Isolated media-path matrix

Run publisher and subscriber checks with synthetic clients in an isolated test deployment. Reuse the #158 warm-up, sampling and repeat schedule. Record each role separately because publisher and subscriber transports can differ.

| Scenario | Sanitized path class | Playback evidence |
|---|---|---|
| UDP available | `direct_udp` | Selected pair, bidirectional audio/video, RTT, loss and freeze observations |
| UDP blocked, TCP available | `ice_tcp` | Selected pair and paired playback observations |
| TURN over UDP configured | `turn_udp` | Selected relay pair and paired playback observations |
| TURN over TLS configured | `turn_tls` | Selected relay pair and paired playback observations |

Record only the fixed path class, transport class, publisher/subscriber role, test result and aggregate measurements. Never retain or export candidate addresses, candidate IDs, SDP, TURN usernames/passwords, tokens, domains, public endpoints or per-user/session identifiers. A connection success without a selected pair and paired playback result does not pass a path scenario.

## Deployment and resource checks

- Compare pinned image digests, effective media port mappings, advertised-IP behavior, NAT/firewall rules, proxy/TLS routing, TURN topology and monitoring targets against the versioned repository model. Do not print raw config or environment values into CI logs.
- Confirm inbound media UDP and the configured ICE/TCP fallback from the isolated clients. Treat direct UDP, ICE/TCP and TURN as distinct paths. If TURN/TLS needs port 443, use a dedicated IP or supported layer-4 frontend; do not share the Caddy HTTP listener or use an ordinary HTTP reverse proxy.
- Record IPv4/IPv6 reachability, MTU symptoms, UDP socket drops/queues, retransmissions, SFU CPU throttling/scheduling, RSS, file descriptors, NIC bytes/drops and allocated media ports. Keep interface addresses and host identifiers out of shared evidence.
- Change MTU, socket buffers, port ranges, host networking or UDP mux only after a reproducible isolated A/B. Do not add an unauthenticated TURN relay. Use LiveKit's authenticated embedded TURN or another supported authenticated service with short-lived credentials and bounded relay allocations.
- Estimate capacity from active upstream layers and actually selected downstream subscriptions, then add voice, retransmission, TURN-hop and preview budgets. Do not infer capacity from port count or publishers multiplied by viewers.

## Acceptance and rollback

Pass only after all configured path scenarios have selected-pair and paired-playback evidence, private metrics scrape and alerts have been observed, and a test deployment has passed the normal versioned release workflow with rollback exercised. Compare loss, RTT, freezes and host/SFU resources to the #158 baseline. Set degradation thresholds from measured baseline and product SLOs; this repository does not define a numeric media SLO.

If a deployment change fails acceptance, use the deployment workflow's pinned previous configuration and image digest, verify service health, then repeat the same isolated path checks. Record `NOT_RUN` when test infrastructure or devices are unavailable. Keep the issue open until its deployment, security and runtime gates have direct evidence.
