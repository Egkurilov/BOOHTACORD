# Voice roster #268/#269 development evidence

Date: 2026-10-08. Branch: `codex/finish-roster-backend`; base: `b0bbe27a`.
Class: `split_first`; native routes: watcher, roster list, volatile SFU gate,
RoomService failure classifier, roster telemetry. Stop: bounded safe recovery,
typed private attribution, native/race checks and explicit remaining acceptance.

Preservation baseline: PR #279 already emits `roster-unavailable` then closes;
SSE snapshot and session-expired data schemas remain unchanged. Per-user ACL,
active lease checks before/after SFU, signed webhook verification and privacy
stay in the real services. Authorized rosters are never cached between users.

## Implemented

- Initial DB/SFU dependency failures are typed internally and return 503 with
  Retry-After:1 and server-generated X-Request-ID. Known SFU validation/token
  defects and unclassified internal defects return 500. Public detail stays
  generic; bounded stages also annotate request-correlated failure trace events.
- Transient refresh gets one retry after 300–399ms within the original five
  seconds. Cancellation stops backoff. Exhaustion sends unavailable, closes,
  and never fabricates an empty roster or session-expired. Socket writes have
  a three-second deadline, tested with a real client that does not read.
- Equivalent scopes share SFU observations; at most four refreshes execute,
  16 scope entries are retained, no queue/bypass or unlimited detached jobs.
  250ms success/failure cooldown does not return partial/error payloads.
  Last-waiter cancellation aborts fetch; verified notification clears cache
  and prevents pending cache fill. Reconciliation jitter is 4.75–5 seconds.
- OTel and private Prometheus observe initial outcomes, active/ended streams,
  last authorized success, installed-observer marker, SFU method timing/count,
  gate budget, bounded transport and HTTP failure classes, configuration and
  last attempt/success. Names follow voice_platform_voice_roster_* and
  voice_platform_sfu_room_service_*. Initial success/failure/canceled counters
  and active stream gauge start at zero; last authorized success zero means
  no success observed. Idle requires active streams before freshness alerts.

## Observed verification

PASS: nearest watcher/roster/SFU/gate/classifier/telemetry/app Go tests and vet.
PASS: full backend `go test ./...`; unavailable unrelated external integration
fixtures can skip in this broad command, so this is not production acceptance.
PASS: WSL Ubuntu pinned Go1.26.4 + gcc `go test -race` for watcher, roster list,
SFU/gate/classifier, http metrics, roster telemetry and app composition.
PASS: actual isolated PostgreSQL17 test
`TestPostgresRosterExcludesRevokedBlockedAndArchivedState` (7.02s), including
session revoke, blocked account, voice lease revoke and archived channel.
PASS: contract verifier (19 checks; 90 public operations, three exclusions).
PASS: negative privacy/event/trace tests, webhook/cache invalidation, cancellation,
missed notification reconciliation, heartbeat, revoke and backpressure checks.

`synthetic-fanout.txt` records 20 bursts per case, watchers=1/10/25/50/100 and
scope rooms=0/1/5/20. Coalesced cost is one source call/burst; uncoalesced reference
cost is watcher count. The reference is intentionally a direct source harness,
not the old deployed gate (which already coalesced one equivalent scope).
Reported nanoseconds are local synthetic scheduling cost, not network latency,
SFU RPC count, SFU load capacity or production before/after baseline.

## Remaining acceptance

NOT_RUN here: equivalent staging/production watcher/room baseline and post-fix
with CPU/RAM, PostgreSQL acquisition wait, RoomService RPS/p95, reconnect/webhook
bursts and measured roster freshness. SLO thresholds need those measured
conditions; the tests do not assert hardware capacity. Production incident RCA,
browser/Flutter device behavior and central Grafana delivery belong to the
coordinating packet and its QA-only follow-up. No production deploy was made
by this leaf worker. No reference or issue was edited to make checks pass.

Slavik Gym report: route=watch_connected_participants+list_connected_participants+
coalesce_presence_snapshot+snapshot_livekit_presence+classify_room_service_failure+
roster_stream_metrics; packet=268-269-development; tokens=estimated:18000;
method=manual_estimate; driver=Codex leaf worker; next_split=production baseline QA.
