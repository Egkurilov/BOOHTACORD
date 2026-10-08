# #266 / #267 read-only production observations

Outcome: PARTIAL. Current observations PASS; root cause and authenticated API
REST/SSE comparison remain NOT_RUN. No deployment configuration fix is claimed.

## Source and effective deployment

Observed 2026-10-08 20:24–20:35 UTC, API/Web host 176.108.242.211.
API running source label `ac8ff3d3d62bd5f98b32e7b229a8d0914c779dfa`.
API image `sha256:a48497dd3884fad55d40b33070b6437400dbfab14356d0dcc2f9ccd0feb0e3ae`.
LiveKit image `sha256:6fd3b7088874c4d119160dd688798dfec852bc014786d392caad15f6f63912a3`.
API/SFU share `voice-platform_private`; API also has telemetry-egress.
SFU currently also attaches edge (repository model excludes it); no change made.
Private endpoint: `http://livekit:7880`. Process environment and Docker config
agree for private endpoint/key/secret and proxy keys (comparison only, no secrets).
API, SFU, DB and proxy restart count zero; OOM false; PostgreSQL healthy.
Public `/healthz`: 200 (liveness only).

## Actual dependency comparisons

- Private authenticated ListRooms from the proxy container: exit 0, 68 ms,
  one room. Credential existed only in memory/stdin; no secret evidence retained.
- A temporary static diagnostic built from integration base
  `b0bbe27a4618eb831dd33e1e4f2b0ea98488921b` invoked the exact Go snapshot
  client from the API network namespace, using the running API configuration.
  A disposable read-only, capability-free container ran with 128 MB / 0.5 CPU.
- Exact Go Snapshot: ListRooms 200, ListParticipants 200, two participants / two
  tracks, 4 ms. Scoped SnapshotRooms: six channel IDs requested internally,
  one room returned, success. IDs/names/token/participant details not retained.
- Actual API counters first observed: ListRooms failures 2460; roster
  presence_room_list failures 2466; nearly every failed snapshot below 5 ms.
  Later: ListRooms failures 2582 and successes 73; participant successes 73.
- Bounded LiveKit log inspection: 133 ListRooms service records all status 200.
  API process emitted no comparable dependency failure details. Failure transport
  or HTTP status cannot be inferred from these old boolean outcome metrics.

These observations reject a permanent missing private endpoint, permanent wrong
key/secret, and permanent DB/SFU disconnection during successful probe times.
They do not reject intermittent failure, differences in cancellation/transport,
proxy/session behavior, stale connections, or resource pressure between probes.
The original authenticated 503 has not been reproduced with a permitted existing
API session in this packet. No user impersonation/session creation performed.

## Observability gap

Host 167.233.56.32 private Prometheus targets: Collector, Tempo, Prometheus;
all up. No API scrape target. Old roster instruments are Prometheus-only and
therefore unavailable centrally. #268/#271 source work adds authenticated OTLP
roster observations with bounded transport/HTTP error classes and freshness.
The gap is confirmed; it is not established as the cause of the UI failure.

## Decision and remaining evidence

`NO_CONFIG_CHANGE`: no demonstrated endpoint/credential/network configuration
cause. Next: deploy reviewed diagnostic/recovery source; correlate actual bounded
outcome metrics with one authorized REST/SSE failure, then make only the proved
fix. #266/#267 stay open. No production restarts, schema writes, user mutations,
management-port publication or physical/media capacity claim in this packet.

Temporary diagnostic container was automatically removed. Its nonsecret binary
under `/tmp/boohtacord-roster-probe-oct08` is scheduled for removal after comparison.
