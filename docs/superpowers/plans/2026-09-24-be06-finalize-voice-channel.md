# BE-06 Voice Channel Finalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide a closed VOICE channel automatically only after durable SFU revocations and a private LiveKit room query confirm that no participants remain.

**Architecture:** The existing close-admission command is phase one and continues to return the pending state. A bounded worker selects closed candidates whose active leases and pending SFU revocations are zero, queries the exact LiveKit room, then archives under the existing topology advisory lock with the database guards repeated. An absent room is empty only when RoomService `ListRooms` successfully confirms absence. After commit, the worker emits revisioned `channel.updated`; failed SFU or RoomService calls leave the channel visible.

**Tech Stack:** Go 1.26, pgx/PostgreSQL, LiveKit RoomService, existing realtime event hub.

---

### Task 1: Authoritative exact-room presence

**Files:** Create `backend/internal/media/snapshot_livekit_presence/room_participants.go` and `room_participants_test.go`; reuse `client.go`'s token and RoomService helpers.

- [x] **Step 1: Write failing tests** for `CountRoomParticipants(ctx, channelID) (int,error)`: `ListRoomsRequest.Names` is exactly `voice:<UUID>`, absent room returns zero without `ListParticipants`, present room returns actual participant count using a room-scoped `RoomAdmin` credential, invalid UUID and RoomService errors fail closed. The test server asserts `claims.Video.RoomList` for `ListRooms` and `claims.Video.RoomAdmin && claims.Video.Room == testRoom` for `ListParticipants`.
- [x] **Step 2: Run** `go test ./internal/media/snapshot_livekit_presence -run TestCountRoomParticipants -count=1`; expected and observed: missing method.
- [x] **Step 3: Implement** exact-room `ListRooms` and, when found, `ListParticipants`. Core request: `ListRooms(ctx, &livekit.ListRoomsRequest{Names: []string{"voice:" + channelID}})`. Return `ErrUnavailable` on nil responses, unexpected room names, and private API errors.
- [x] **Step 4: Rerun** the same test; observed: PASS.

### Task 2: Bounded candidate and guarded finalization

**Files:** Create `backend/internal/channel/finalize_closed_voice_channel/service.go`, `service_test.go`, `postgres/queries.go`, `repository.go`, `repository_test.go`, `repository_fakes_test.go`, `pool_database.go`, `integration_fixture_test.go`, and `repository_integration_test.go`.

- [x] **Step 1: Write failing service tests**: zero participants calls finalization; connected participants and RoomService errors never archive or publish; duplicate finalization returns zero; keyset scan reaches later rooms despite occupied earlier rooms.
- [x] **Step 2: Run** `go test ./internal/channel/finalize_closed_voice_channel/... -count=1`; expected and observed: missing package/methods.
- [x] **Step 3: Implement** `Run(ctx,limit)` with `1 <= limit <= 100`, `Candidates(ctx,limit,after)`, `CountRoomParticipants(ctx,channelID)`, `Finalize(ctx,channelID)`, and `PublishTopologyRevision(revision)`. Keep the last scanned channel ID as a keyset cursor and restart after an empty page; unavailable presence returns an error without archiving.
- [x] **Step 4: Write repository tests** requiring `NOT EXISTS (SELECT 1 FROM voice_leases AS lease WHERE lease.channel_id = channel.id AND lease.revoked_at IS NULL)` and the same guard for `voice_sfu_revocations AS revocation` with `completed_at IS NULL`. Test lock, one revision/audit, commit-before-return, and `pgx.ErrNoRows` as an idempotent no-op.
- [x] **Step 5: Implement** parameterized SQL and pgx adapter. Candidate SQL is keyset ordered by `channel.id`; final SQL repeats guards while holding advisory lock `441903817` and writes `VOICE_CHANNEL_ARCHIVED` with only `channel_id` metadata.
- [x] **Step 6: Run** `go test ./internal/channel/finalize_closed_voice_channel/... -count=1`; observed: PASS.

### Task 3: Automatic worker and post-commit event

**Files:** Create `backend/cmd/api/voice_channel_finalization_worker.go` and `voice_channel_finalization_worker_test.go`. Root wires `main.go` after BE-14's edit.

- [x] **Step 1: Write failing worker tests** asserting startup call, bounded limit and context deadline, plus a `channel.updated` payload containing only the revision.
- [x] **Step 2: Run** `go test ./cmd/api -run TestVoiceChannelFinalization -count=1`; expected and observed: missing worker.
- [x] **Step 3: Implement** `startVoiceChannelFinalizationWorker(parent, finalizer)` with separate 15-second poll and five-second attempt deadline. The publisher emits `eventhub.Event{Kind: "channel.updated", Payload: map[string]any{"revision": revision}}`; the service invokes it only after committed `Finalize` returns a nonzero revision.
- [x] **Step 4: Run** `go test ./cmd/api -run TestVoiceChannelFinalization -count=1`; observed: PASS.
- [x] **Step 5: Tell root** to wire `startVoiceChannelFinalizationWorker(context.Background(), newVoiceChannelFinalizer(database, configuration.mediaSnapshot, events))` and defer its returned cancel function after BE-14's `main.go` changes. No extra imports needed.

### Task 4: Native verification and evidence

- [x] **Step 1: Run** `go test ./internal/channel/finalize_closed_voice_channel/... ./internal/media/snapshot_livekit_presence ./cmd/api -count=1` and `go vet ./internal/channel/finalize_closed_voice_channel/... ./internal/media/snapshot_livekit_presence ./cmd/api`; observed: PASS.
- [x] **Step 2: Run isolated-schema PostgreSQL integration** with `VOICE_PLATFORM_TEST_DATABASE_URL` set to a loopback disposable database; observed: PASS for pending SFU row, active lease, one revision/audit, idempotent replay, and list-topology omission. The exact test URL is kept out of this plan.
- [x] **Step 3: Confirm** existing close-admission response and signal guard remain unchanged, no admin endpoint was introduced, and `authorize_livekit_signal` focused tests pass.
