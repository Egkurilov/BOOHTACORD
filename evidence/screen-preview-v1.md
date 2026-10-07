# Screen-preview v1 evidence

Issue: GitHub #163. Scope: authenticated preview-generation API, current LiveKit publication binding, bounded ephemeral JPEG cache, targeted realtime hints, and Web/Flutter sender plus protected-card integration.

## Local checks

- `go test ./internal/app/media_routes/... ./internal/app/runtime ./internal/config/runtime ./internal/media/screen_preview/... ./internal/realtime/event_hub`: PASS, including the moved `media_routes/screen_preview` hint publisher package.
- Earlier full Web baseline: PASS (392 files, 1209 tests). Current focused preview tests: PASS (4 files, 12 tests), including bounded uploader shutdown and latest-wins behavior. Preview files now live under `clients/web/src/voice/screen_preview`.
- Web `VITE_PUBLIC_ORIGIN=https://preview.invalid npm run build`: PASS. Vite reports the existing LiveKit dynamic-import and large-chunk warnings.
- Flutter `flutter test test/screen_preview_client_test.dart test/screen_preview_sender_stop_test.dart`: NOT_RUN; Flutter/Dart SDK is unavailable on this Windows host. Tests cover authenticated sender routes, latest-wins queueing, and shared stop callers waiting for DELETE completion.
- `git diff --check`: PASS.
- OpenAPI/realtime contract validation and `tools/verify/spec_traceability/verify-spec-traceability.ps1`: PASS.

## Acceptance not run

- Real Postgres negative authorization integration and revoked-session race: NOT_RUN.
- Real private LiveKit RoomService against active, muted, replaced and absent publications: NOT_RUN (only a synthetic RoomService fixture was used).
- Browser/Flutter device acceptance and visible-card QA: NOT_RUN. Source wiring consumes private JPEG HTTP reads on metadata hints and never subscribes to preview video; automated server/device RTP subscription-count evidence is not available on this host.
- 20-publisher load, peak cache/timer memory, Android/desktop device checks and production revoke timing: NOT_RUN.
- Flutter sender tests (authenticated upload route, one-in-flight/latest-wins behavior and invalidation barrier): NOT_RUN; Flutter/Dart SDKs are not installed on this host.
- Multi-process API behavior: NOT_RUN; implementation uses one bounded in-process cache and requires the current single API process deployment.

The server emits ephemeral `screen_preview.updated` and `screen_preview.invalidated` hints only to active voice-lease accounts in the same open channel; a realtime capability gates delivery to updated clients. Event payloads contain only lease/generation/revision metadata. Clients poll a known generation as a bounded fallback and clear cards on invalidation/expired access. Web and Flutter upload through bounded latest-wins queues from existing local thumbnail samplers; protected reads populate existing in-memory card thumbnail maps without subscribing to screen video. Web room shutdown and disconnect paths abort in-flight preview requests and wait up to 250 ms for them, then attempt generation invalidation with a further 250 ms bound before voice-lease release. If a begin response arrives after stop, the returned generation is invalidated asynchronously; if its identifier never arrives or invalidation cannot reach the server, protected reads fail after lease revocation and cached bytes expire by the server's 15-second TTL. This is a bounded teardown guarantee, not proof that the remote cache was synchronously erased under network failure. Flutter screen teardown and failed admission finalization still await the thumbnail uploader cleanup barrier before release. Concurrent stop callers share one invalidation operation. Web tests verify bounded shutdown and latest-wins behavior; the new Flutter barrier test is NOT_RUN because its SDK is unavailable. JPEG inputs in tests are synthetic. No image bytes, credentials, account IDs, lease IDs or track identifiers are logged or sent as telemetry. This record does not close issue #163.
