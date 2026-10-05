# ADR-017: conditional embedded LiveKit TURN/TLS for restricted networks

Date: 2026-10-05. Status: **PROPOSED, conditional; production promotion pending**.
Owner: IMP-31 / issue 95; dependencies: QA-06, QA-09, QA-10.

## Measured context

[Isolated evidence](../../evidence/issue-95-restricted-networks-2026-10-05.md)
confirms real Chromium/LiveKit RTP over UDP and TCP fallback when UDP is blocked.
Blocking both media transports permits signal but prevents ICE/media; restoring
transport permits a fresh join. This is an owned Linux namespace experiment,
not evidence of home/hotspot failure, corporate proxy traversal or production TLS.

Current deployment exposes SFU UDP 50000–50100 and ICE/TCP 7882. HTTPS on 443
terminates at Caddy: `/rtc` uses server-side admission then forwards signal.
That HTTP route cannot carry raw TURN/TLS. Increasing join retries cannot create
a usable media path when the permitted transports are absent.

## Conditional decision

Keep direct UDP and current ICE/TCP fallback. If a real affected network confirms
successful authorized WSS but blocked media, propose the **embedded LiveKit
TURN/TLS** transport on TCP 443. Do not add an external TURN implementation,
Redis, HA or a Go media proxy. Until the following gates pass, the production
configuration remains unchanged and issue 95 remains open.

## Route 443 and certificate

Preferred single-SFU topology: dedicate a second public IP and TURN hostname to
the existing LiveKit instance. Bind Caddy explicitly to the primary IP and expose
the SFU TURN/TLS listener as secondary-IP:443. Keep signal behind Caddy admission
on the primary IP. Verify port conflicts and published management boundaries
before changing either binding. DNS points the TURN hostname to its own IP.

An alternative same-IP:443 L4/SNI demultiplexer needs a separately reviewed
topology, certificate ownership and rollback before adoption; the current Caddy
HTTP reverse proxy is insufficient. Do not silently move TURN to an arbitrary
high port and claim secure-TCP-only networks supported.

Use a trusted CA certificate matching the TURN hostname, distinct from the
application hostname. Mount certificate/key read-only, validate SAN/expiry and
renewal, and rehearse renewal without publishing credentials. No key in Git,
browser evidence or CI artifacts. TURN must be advertised only after its DNS,
certificate and 443 route pass checks. Preserve pinned SFU releases.

## Admission, ACL and revocation

Use LiveKit's embedded authenticated TURN credentials issued after its signal
connection, reached through the existing session/Origin/CSRF/voice-lease gate.
Never expose the SFU management endpoint or mint TURN credentials in an anonymous
API. Existing channel membership, participant-only DM rules and listen-only
publication policy remain server-owned.

Measure on a real relay-selected connection: admission denied without session,
blocked account, lease transfer, channel close, logout and password reset remove
voice/media rights. Test replay of old signal/media credentials, credential
expiry, existing allocations and allocation cleanup. TURN allocation lifetime
is not equivalent to room ACL validity; do not promise immediate allocation
revocation without evidence. Retain unknown results as QA-10 NOT_RUN/NO_GO.

## Relay traffic, cost and capacity

Use bounded counts/rates, bytes and CPU; never candidate addresses, user/room
labels or media content. Measure SFU ingress/egress and NIC traffic separately
from RTP payload, including TLS/TCP overhead and retransmission. Track what
fraction actually selects relay, concurrency, duration and screen publications.
Estimate provider cost from measured billable egress and the actual tariff;
no numeric cost or 100-participant capacity is asserted by this ADR.

Run the agreed QA-09 profile only on authorized hardware, including concurrent
voice, selected screens and mixed direct/relay connections. Measure latency,
jitter/loss, CPU, memory, network/quota and failure/recovery. Prefer voice under
congestion; no extra stream quota or changed quality promise.

## Promotion and rollback gates

1. Home/hotspot and a real restricted network: source-bound signal/ICE/RTP
   reports, selected `relay` candidate and approved listener confirmation.
2. QA-06 capture/audio continuity, QA-09 hardware capacity and QA-10 revoked
   membership/credential replay/expiry on TURN, all with applicable evidence.
3. DNS/certificate/443 binding preflight; private management unchanged.
4. Opt-in canary and rollback: stop advertising TURN, keep direct transports,
   remove only the TURN mapping/config, retain DB and attachment volumes.

References: [LiveKit ports](https://docs.livekit.io/transport/self-hosting/ports-firewall/),
[deployment](https://docs.livekit.io/transport/self-hosting/deployment/),
[ADR-005](ADR-005-self-hosted-livekit-revocation.md),
[operator protocol](../runbooks/restricted-networks.md).
