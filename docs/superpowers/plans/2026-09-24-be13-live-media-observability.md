# BE-13 Live Media Observability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export actual LiveKit voice participant, active media-track and screen-stream counts, realtime reconnect outcomes, and successful event-delivery latency through the existing private metrics endpoint.

**Architecture:** A narrowly scoped RoomService client lists active `voice:<channel UUID>` rooms and then each room's actual participants/tracks. A no-label collector reads that source with a deadline on private `/metrics` scrapes, emits a success gauge, and omits count samples on failure so unavailable data cannot be mistaken for zero. Recorder methods accept only fixed reconnect outcomes and measured successful WebSocket delivery durations; separate realtime owners wire those hooks.

**Tech Stack:** Go 1.26, `github.com/livekit/protocol` RoomService and auth, `prometheus/client_golang`, `net/http/httptest`, repository-native Go tests.

---

### Task 1: Authoritative LiveKit snapshot leaf

**Files:**
- Create: `backend/internal/media/snapshot_livekit_presence/client.go`
- Create: `backend/internal/media/snapshot_livekit_presence/client_test.go`

- [x] **Step 1: Write a failing test.** Use an `httptest.Server` that serves `ListRooms` with one `voice:<UUID>` room and one unrelated room, and `ListParticipants` with two connected participants where one publishes an unmuted screen-share video track, microphone audio track and screen-share audio track. Verify `Snapshot(context.Background())` yields `{Participants: 2, Streams: 3, ScreenStreams: 1}` and requests carry scoped grants (`RoomList` for room listing, `RoomAdmin` bound to the exact voice room for participant listing). Add a failure test where `ListParticipants` fails: the snapshot must return an error, never a partial count.
- [x] **Step 2: Run the red test.** `cd backend; go test ./internal/media/snapshot_livekit_presence -count=1`; expected build failure before implementation.
- [x] **Step 3: Implement the client.** Define `Config{URL,APIKey,APISecret string}`, `Snapshot{Participants,Streams,ScreenStreams int}`, `New(Config) (Client,error)`, and `Client.Snapshot(context.Context) (Snapshot,error)`. Validate private HTTP(S) endpoint and credentials. Use `auth.NewAccessToken(...).SetVideoGrant(&auth.VideoGrant{RoomList:true})` for `ListRooms`, and a fresh token with `RoomAdmin:true,Room:roomName` for each `ListParticipants`. Count only active voice rooms named `voice:` plus a valid UUID, all unmuted AUDIO/VIDEO tracks, and SCREEN_SHARE video as a subset; return an error on any failed RPC.
- [x] **Step 4: Run the green test.** `cd backend; go test ./internal/media/snapshot_livekit_presence -count=1`; expected PASS.

### Task 2: Private no-data-aware Prometheus collector

**Files:**
- Create: `backend/internal/observability/http_metrics/voice_media.go`
- Create: `backend/internal/observability/http_metrics/voice_media_test.go`
- Modify: `backend/internal/observability/http_metrics/recorder.go`

- [x] **Step 1: Write failing tests.** Register a fake `VoiceMediaSource` returning `VoiceMediaSnapshot{Participants:2,Streams:3,ScreenStreams:1}`; scrape and assert `voice_platform_voice_media_snapshot_success 1`, `voice_platform_voice_participants_active 2`, `voice_platform_voice_streams_active 3`, and `voice_platform_voice_screen_streams_active 1`. On fake error, assert success `0` and no count samples. Reject nil and duplicate registration. Assert no account, room, lease or error strings appear in scrape.
- [x] **Step 2: Run the red test.** `cd backend; go test ./internal/observability/http_metrics -count=1`; expected build failure before registration API.
- [x] **Step 3: Implement the collector.** Define `VoiceMediaSource.Snapshot(context.Context) (VoiceMediaSnapshot,error)`, call with a five-second timeout in `Collect`, validate nonnegative counts, emit one no-label success gauge and the three no-label counts only on complete success. Add `RegisterVoiceMedia(VoiceMediaSource) error` to `Recorder`, guarded against nil and duplicate source.
- [x] **Step 4: Run the green test.** `cd backend; go test ./internal/observability/http_metrics -count=1`; expected PASS.

### Task 3: Bounded reconnect and delivery latency metrics

**Files:**
- Create: `backend/internal/observability/http_metrics/realtime_outcomes.go`
- Create: `backend/internal/observability/http_metrics/realtime_outcomes_test.go`
- Modify: `backend/internal/observability/http_metrics/recorder.go`

- [x] **Step 1: Write failing tests.** `ObserveRealtimeReconnectOutcome("replayed")`, `("resync_required")`, `("rejected")`, and one arbitrary value; assert only three fixed label values appear. `ObserveRealtimeEventDeliveryLatency(25*time.Millisecond)` and negative duration; assert histogram count is exactly one and no event kind, user ID or DM ID labels appear.
- [x] **Step 2: Run the red test.** `cd backend; go test ./internal/observability/http_metrics -count=1`; expected build failure before methods.
- [x] **Step 3: Implement recorder methods.** Register `voice_platform_realtime_reconnect_outcomes_total{outcome}` with only `replayed`, `resync_required`, `rejected`; reject every other caller-supplied string. Register no-label `voice_platform_realtime_event_delivery_seconds` histogram and observe finite, nonnegative durations only.
- [x] **Step 4: Run the green test.** `cd backend; go test ./internal/observability/http_metrics -count=1`; expected PASS.

### Task 4: Composition and native checks

**Files:**
- Modify: `backend/cmd/api/runtime_configuration.go`
- Modify: `backend/cmd/api/main.go`
- Create: `backend/cmd/api/voice_media_metrics.go`
- Create: `evidence/observability-be13-2026-09-24-001.json`

- [x] **Step 1: Wire the source.** Build `snapshotlivekitpresence.New(snapshotlivekitpresence.Config{URL:os.Getenv("LIVEKIT_PRIVATE_HTTP_URL"),APIKey:os.Getenv("LIVEKIT_API_KEY"),APISecret:os.Getenv("LIVEKIT_API_SECRET")})` in `loadRuntimeConfiguration`. Add `voiceMediaMetricsSource` in `voice_media_metrics.go` to convert `snapshotlivekitpresence.Snapshot` to `httpmetrics.VoiceMediaSnapshot`, then register it before status routes. Startup must fail on invalid configuration/registration, while a runtime RoomService outage affects only success/count metrics.
- [ ] **Step 2: Coordinate realtime callsites.** BE-02 now invokes `ObserveRealtimeEventDeliveryLatency(time.Since(event.OccurredAt))` only after a successful published-event WebSocket write. BE-14 owns reconnect semantics and must call `ObserveRealtimeReconnectOutcome` only after the actual resume outcome is known; never count a plain first connection as reconnect.
- [x] **Step 3: Format and validate.** From `backend`, format touched Go files and run `go test ./internal/media/snapshot_livekit_presence ./internal/observability/http_metrics ./internal/realtime/connect_session ./cmd/api -count=1` plus `go vet` on the same packages; expected PASS. From repository root, run `git diff --check` on touched source; expected no errors. Record local PASS and production private scrape NOT_RUN in the evidence file.

**Review:** REQ-OPS-01 has source/recorder implementation and focused tests. BE-14 still needs to connect the fixed reconnect outcome API to the resume decision. There are no free-form labels, lease-derived media counts, public metrics route changes, or user-content fields. Real LiveKit production scrape is `NOT_RUN` in the evidence record.
