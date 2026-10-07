# Screen-preview v1 evidence

Issue: GitHub #163. Scope: authenticated preview-generation API, current LiveKit publication binding, bounded ephemeral JPEG cache, targeted realtime hints, and Web/Flutter sender plus protected-card integration.

## Local checks

- `go test ./internal/app/media_routes ./internal/app/runtime ./internal/config/runtime ./internal/media/screen_preview/... ./internal/realtime/event_hub`: PASS (focused packages; runtime package compiled, but its composition test has a Linux build tag).
- Web screen-preview and realtime contract tests: PASS (14 tests).
- Web typecheck/build: PASS (`VITE_PUBLIC_ORIGIN=https://preview.invalid npm run build`; Vite reports existing LiveKit dynamic-import and large-chunk warnings).
- Flutter sender/receiver tests: NOT_RUN; Flutter 3.47.5 is not installed on this Windows host. Focused tests cover authenticated sender routes and latest-wins queueing but were not executable here.
- OpenAPI/realtime contract validation and `tools/verify/spec_traceability/verify-spec-traceability.ps1`: PASS.

## Acceptance not run

- Real Postgres negative authorization integration and revoked-session race: NOT_RUN.
- Real private LiveKit RoomService against active, muted, replaced and absent publications: NOT_RUN (only a synthetic RoomService fixture was used).
- Browser/Flutter device acceptance and visible-card QA: NOT_RUN. Source wiring consumes private JPEG HTTP reads on metadata hints and never subscribes to preview video; automated server/device RTP subscription-count evidence is not available on this host.
- 20-publisher load, peak cache/timer memory, Android/desktop device checks and production revoke timing: NOT_RUN.
- Flutter sender unit test (authenticated upload route and one-in-flight/latest-wins behavior): NOT_RUN; Flutter/Dart SDKs are not installed on this host.
- Multi-process API behavior: NOT_RUN; implementation uses one bounded in-process cache and requires the current single API process deployment.

The server emits ephemeral `screen_preview.updated` and `screen_preview.invalidated` hints only to active voice-lease accounts in the same open channel; a realtime capability gates delivery to updated clients. Event payloads contain only lease/generation/revision metadata. Clients poll a known generation as a bounded fallback and clear cards on invalidation/expired access. Web and Flutter upload through bounded latest-wins queues from existing local thumbnail samplers; protected reads populate existing in-memory card thumbnail maps without subscribing to screen video. Flutter sender invalidates its exact generation on screen stop/unpublish or voice-lease changes, and receiver timers/card bytes clear on room admission, leave and controller disposal. Web tests passed the uploader queue behavior. JPEG inputs in tests are synthetic. No image bytes, credentials, account IDs, lease IDs or track identifiers are logged or sent as telemetry. This record does not close issue #163.
