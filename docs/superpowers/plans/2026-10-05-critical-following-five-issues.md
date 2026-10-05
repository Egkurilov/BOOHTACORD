# Following five critical issues implementation plan

> Execute inline, one leaf and its native checks at a time. Previous PR #129 acceptance runs independently.

**Goal:** Implement #67, #73, #84, #91 and #99 while preserving ACL, chat counters and media ownership.
**Architecture:** Use existing optimistic revisions, secure sessions, leases and media controllers.
Add bounded leaf capabilities around their native edges; private readiness never changes public liveness.
**Tech Stack:** Vue 3/TypeScript/Pinia, Go/PostgreSQL/LiveKit, native Chromium integration.

## Operating brief

Route=split_first; implementation, verification and branch_sync are separate packets.
Baseline=5464e5ed; branch=codex/critical-following-five-issues; primary checkout is preserved.
Instructions=AGENTS.md/SKILL.md/structure.config.yaml and native manifests.
Ratchet=100 target/120 hard lines; 8 target/16 hard production files and direct tests per leaf.
Search=exact capability files and imports below; no repository-wide source search.
Tasks=T-014/T-020/T-022/T-030/T-040/T-041/T-044/T-050 and their existing dependencies.
Stop=five implemented scopes, observed checks and source-bound receipts; physical release gates stay explicit.

## #73 — conversation notification preferences

Files: notification/{notification_store,notification_delivery,NotificationSettings}.ts/vue;
new notification/conversation_preferences/{policy,state,Settings}.ts/vue and direct tests;
voice/stream_start_runtime.ts reuses its separate existing sound setting.

- [ ] Baseline `npm test -- src/notification src/voice/stream_start_chime.spec.ts` (PASS).
- [ ] Add RED tests: all/mentions/none, pause expiry, corrupt storage, bounded account isolation.
  Core assertion: `expect(policy({mode:'none',pausedUntil:0},false,Date.now())).toBe(false)`.
- [ ] Add RED delayed-lock tests: change preferences before unlock; suppressed IDs remain unclaimed.
- [ ] Implement account-scoped bounded metadata preferences; verify exact mentions through protected message context.
- [ ] Filter before welcome lookup, lock and seen-ID write; recheck inside the native Web Lock.
- [ ] Add TEXT/DM settings and pause controls; preserve counters and permission-on-explicit-enable.
- [ ] Run focused tests/build; exercise two native tabs, pause/logout/account switch on an owned fixture.

## #84 — explicit voice transfer

Files: voice/{connection_store,VoicePrejoin,voice_session,admission_client}.ts/vue;
new voice/controller_ownership/{lease,state,confirm}.ts/vue with focused race tests.

- [ ] Baseline native admission/connection/revocation tests (PASS); retain generation guards.
- [ ] Add RED tests: second tab uses transfer=false; cancel acquires/releases nothing.
  Core assertion: `expect(acquire).toHaveBeenCalledWith(channelId,false)`.
- [ ] Claim origin media ownership explicitly using Web Locks and bounded metadata signalling.
- [ ] Show current room/controller owner and confirmation; only confirmed transfer requests transfer=true.
- [ ] Split oversized native composition by join/processing/reporting ownership while preserving tests.
- [ ] Verify leave/transfer race, one replacement lease, old reconnect rejection and logout cleanup.
- [ ] Run native Go/Web tests and actual same-cookie tabs against real SFU; record independent observations.

## #67 — review optimistic conflicts and voice closure phases

Files: channel/{channel_rename_editor,channel_order_editor,voice_close_editor}.ts and UI callers;
admin/members/AdminMembersSection.vue; identity/admin_directory_client.ts;
new channel/conflict_review and channel/voice_closure leaves; exact native backend mutation imports.

- [ ] Baseline rename/order/role/close tests and read server revision edges (PASS).
- [ ] Add RED tests: 409 retains baseline, draft and fetched current values; no second write before decision.
- [ ] Render accessible before/current/proposed comparison; explicit discard/reviewed apply actions.
- [ ] Preserve server compare-and-swap for role writes; add it if native role endpoint lacks a revision guard.
- [ ] Expose admission-closed, revoke-pending, verified-room-empty and finalized from authoritative server state.
- [ ] Verify real SFU failure leaves pending, repeat is idempotent and audit does not duplicate.
- [ ] Run closest Go/PostgreSQL/Web tests, contracts and two-administrator native browser checks.

## #99 — state-based viewer diagnosis and private local bundle

Files: voice/{ScreenViewer,use_screen_receiver_diagnostics,screen_receiver_diagnostics,
screen_playback_quality,ScreenReceiverDiagnosticsPanel}.ts/vue;
new voice/viewer_diagnosis/{model,series,bundle,Panel}.ts/vue and tests.

- [ ] Baseline receiver stats/playback/viewer tests (PASS); preserve nullable RTT.
- [ ] Add RED transition tests for no-first-frame, frozen-video, absent-audio and stale metrics.
- [ ] Use sampled monotonic progress and actual playback counters; surface one state-specific action.
- [ ] Keep a short bounded local sample series; export whitelisted numeric/state fields only.
- [ ] Assert bundle excludes SDP/IP/ICE/tokens/account/room/track IDs and content; unknown RTT stays null.
- [ ] Run unit/build and two real receivers with isolated media fault injection; bind receipt to source.

## #91 — private readiness and synthetic journey intervals

Files: backend/internal/app/observability_routes/status_routes.go and runtime/routes.go;
new observability/inspect_readiness leaf; admin/readiness leaf;
new telemetry/journey_intervals leaf and exact native send/connection/viewer entrypoints.

- [ ] Baseline public liveness and existing private admin authorization tests (PASS).
- [ ] Add RED DB/SFU/statfs timeout/error tests; failed/unknown samples never report green or zero.
- [ ] Add authenticated administrator-only fresh readiness summary with bounded age/headroom/pending-revoke.
- [ ] Keep liveness cheap; bound probes/deadlines and retain server ACL and no-store.
- [ ] Measure click→connected, send→ack, accepted→rendered, select→first-frame and reconnect→recovered separately.
- [ ] Export bounded synthetic-only interval observations without IDs/content; preserve approved p95 targets.
- [ ] Validate actual service faults and recovery, native contracts/tests and sanitized evidence.

## Delivery

- [ ] Inspect status and explicit file sizes before each commit; exclude existing clients/web/build.
- [ ] Commit scoped code and source-bound evidence; push code without manual release/deploy.
- [ ] Reconcile current master and previous PR ancestry; attach implementation PR.
- [ ] Mark only accepted scopes complete; report remaining device/production gates accurately.
