# Next five critical issues implementation plan

> Execute inline, task by task, preserving existing native behavior and ACL.

**Goal:** Complete #81, #90, #74, #68 and #70 with native tests and owned actual acceptance.
**Architecture:** Keep database authorization authoritative on every response;
reuse native history, upload and SFU adapters. Preserve business logic and media leases.
**Tech stack:** Go/PostgreSQL, Vue/TypeScript/Pinia, actual Chromium/LiveKit QA.

## Operating brief

Route: split_first; independent leaf packets followed by verification/branch_sync.
Doctrine: native edges, failing focused tests, first-pass preservation.
Limits: target 100/hard 120 lines; target 8/hard 16 production/direct test files per leaf.
Search: exact leaves below, explicit imports and nearest typed tests only.
Stop: five source implementations, observed native/actual results, PR integrated;
physical capacity/device/release gates remain separate.
Baseline: origin/master `0bce9020`; preserve primary checkout and untracked Web build.

## #81 — measured bounded SFU snapshot

Native task: T-022 voice, dependencies T-006/T-020; storage T-044, dependencies T-040/T-041.
Files: media/snapshot_livekit_presence/client.go; app/media_routes/voice_participants_routes.go;
new media/coalesce_presence_snapshot/{gate,copy,gate_test}.go;
observability/http_metrics/voice_roster.go; new tools/qa/sfu_snapshot_measure leaf.

- [ ] Measure real `/voice/participants` at 1/20/100 authenticated HTTP observers;
  report RoomService calls/second and p95 without IDs or credentials.
- [ ] Write cancellation, expiry, different scopes, failure and copy-isolation tests.
- [ ] Only after measured fan-out, wrap shared HTTP/SSE presence in bounded single-flight/TTL.
- [ ] Preserve initial/final repository checks and session middleware/no-store on every response.
- [ ] Verify native Go tests and real SFU outage, revocation/blocking while TTL is live.

## #90 — safe operator cleanup

Files: storage/cleanup_hidden_attachments and cleanup_unattached_attachments services;
their postgres/finalize.go; new storage/inspect_attachment_cleanup leaf;
cmd/cleanup_{hidden,unattached}_attachments/main.go; cmd/cleanup_stale_staging/main.go.

- [ ] Baseline claim fairness, retry and finalization tests.
- [ ] Add regression: newly live link must retain the file; callback executes under row lock.
- [ ] Add aggregate read-only count/bytes/oldest retry/skip reason report; no keys/names.
- [ ] Add bounded staging/UNATTACHED/HIDDEN execution and dry-run modes;
  retain existing execution defaults and explicit orphan recovery semantics.
- [ ] Verify actual PostgreSQL/filesystem unchanged by dry-run, safe races and repeat/retry.

## #74 — managed composer uploads

Files: conversation/text_attachment_queue.ts, TextMessageAttachmentPicker.vue;
direct_message attachment queue/picker exact native counterparts;
new conversation/upload_queue leaf, upload clients, scoped draft/composer edges.

- [ ] Add tests for third-file failure, per-file retry/cancel, pending/failed send gate,
  scope switch, preserved successful IDs, 10 files and progress.
- [ ] Implement one sequential bounded queue, abortable transport and active-composer drop.
- [ ] Wire TEXT/DM UI and drafts; canceled UNATTACHED IDs have no client DELETE.
- [ ] Verify real cancel/reservation release, 507/retry, A→B→A and native build.

## #68 — unread timeline pagination and anchor

Files: conversation/use_unread_boundary.ts; TextConversation.vue/TextHistoryList.vue;
direct_message native counterparts; search/SearchMessageContext.vue;
new conversation/context_timeline leaf; history clients and exact backend pagination edges.

- [ ] Add tests for 100+ unread, forward pages, stable chronological ordering,
  deleted anchor, own messages, hidden tab and unseen tail read gating.
- [ ] Add bounded forward/context pagination preserving existing before/at routes.
- [ ] Render new-message divider, restore memory-only account/scope anchor+offset;
  advance cursor only for visible rows, never unseen latest history behind context.
- [ ] Verify actual PostgreSQL/browser scenarios and contracts when changed.

## #70 — unified message navigation

Files: search/SearchMessageContext.vue/search_context_controller.ts/search_target_store.ts;
conversation/reply_context_navigation.ts; context_timeline leaf and TEXT/DM bindings.

- [ ] Baseline existing loaded reply-jump before refactoring.
- [ ] Add focused tests for reply/search/resource-ID navigation, return anchor and focus,
  tombstone/unavailable response with no DM name disclosure.
- [ ] Reuse protected context timeline; preserve voice lease and selected controller.
- [ ] Verify actual old-page navigation and return, foreign DM denial and keyboard focus.

## Delivery

- [ ] Run focused Go/PostgreSQL/Web tests, full Web/build and native CI.
- [ ] Save source-bound actual reports and update only accepted backlog statuses.
- [ ] Inspect explicit file sizes/status, commit, push and attach PR.
- [ ] Reconcile current master, merge accepted code and close only accepted issue scopes.
