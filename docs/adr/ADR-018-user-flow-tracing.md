# ADR-018: Versioned short user-flow records

Status: accepted implementation policy for #144–155. Base ad63694b.
Schema: contracts/telemetry-flow-v1.json. Fixture validation and generated files are checked in CI.

## Identity and lifecycle
Server derives diagnostic session.id via correlate_session; X-Telemetry-Session on an
authenticated response distributes that non-credential ID. It is not a cookie or token digest.
Random nonzero lowercase 32-hex visit per tab/launch, flow per intent and media session per
join are client claims. Retry reuses flow with incremented attempt (1–20), new intent gets
new flow. Reconnect keeps media session; room/account/origin switch and leave rotate it.
Relay compares every v1 span session.id with the authenticated principal's diagnostic ID.
A stale A batch under B is rejected wholesale. Legacy records stay unowned client claims;
never retroactively assign legacy records to the cookie used at flush time.

## Records and observable results
Actions emit short start/checkpoint/terminal records (<=120s) with IDs, fixed stage,
attempt, outcome and client_observed provenance. No terminal means unknown/incomplete.
Single terminal per attempt; cancel/reject/timeout/superseded are distinct. HTTP completion
does not prove rendering. Join: lease -> credential -> connect -> microphone if needed ->
ready. View: select -> subscribe -> track -> decoded when measurable -> first_frame.
Send: intent -> request -> ack -> render. Startup: local storage and preauth restore
are local only; after the verified receipt, exported readiness covers restore ->
workspace -> mounted render. It does not retroactively measure preauth storage.
Auth: authenticate -> restore -> workspace; preauth spans never acquire an account later.
Admin revoke: authorized commit -> enqueue -> short worker attempt -> SFU API response ->
target observation, only when observed. An SFU response does not prove acoustic silence.

## Async and trust
HTTP uses an explicit captured context and same API origin only, never baggage.
Same-session links inside one sanitized batch are client claims. Cross-user links require
a server-issued audience-bound causal reference delivered only through an authorized
event envelope. Reference authenticates causality, never resource access. Workers persist
only trace/span/flow/version, not contexts/headers/credentials, in their existing transaction.
Each retry is a short span linked to the durable original cause; legacy work remains runnable.

## Privacy and compatibility
Only schema fields/fixed events survive relay; user/name/session supplied by clients are
not trusted. IDs are private span attributes, never resources or metric labels. No URLs,
body, DM IDs, files, device labels, PCM/video, SDP/ICE/IP or exception messages.
Grafana filters are not ACL; telemetry claims are not SFU truth; rendering is not a receipt.
No anonymous endpoint. Preauth/postlogout diagnostics are local only and may be dropped.
Queues are session/origin/generation partitioned; reset drops old data without delaying cleanup.
Budgets: 128 queued, 16/export, 32/relay, 3s timeout, 2 bounded retry attempts, <=256KiB body.
Unknown semantic records can be rejected partially; malformed/oversize/mismatch fails whole batch.
New clients require schema header 1 on auth restore. Roll out relay/backend then clients,
then dashboard. Old relay => disable v1 export, retain product behavior and legacy operations.
Rollback clients/config first; retain nullable metadata columns and relay's legacy sanitization.

## Sampling/access/retention
Pinned SDK versions are native manifests; Collector/Tempo/Grafana versions are compose.
Private operator datasource only; session filter grants nothing. Inherit existing retention
and private credentials. No public snapshots. Bounded synthetic pilot uses full sampling;
production parent-based ratio is configurable, default preserves existing policy. Explicit
disable uses an always-off sampler even for a sampled parent. Fixed, client-observed
export health checkpoints report queue/drop/retry/freshness every 5s under the same
bounded session processor; a complete outage can also lose these checkpoints. No tail
sampling introduced without measured need. Missing/late/dropped records mean incomplete.
Deployment and device evidence are separate from unit tests; no physical media claims.

