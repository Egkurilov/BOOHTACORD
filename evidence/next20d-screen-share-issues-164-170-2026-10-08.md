# Screen-share issue audit: #164–#170

Audit base: local `master` at `0ee991cd42b10f33ac4e5840498a19f5db33d643`.

## Source status

- #164: Web viewer lifecycle and recovery are present in `screen_viewer_lifecycle.ts`; focused lifecycle tests include 100 same-publication selections.
- #165: Flutter viewer generation, serialized renderer binding and retry code are present. Physical cross-client playback remains unverified.
- #166: platform capture plan and explicit update notice are present; native Windows/macOS capture cost and source restart behavior remain unverified.
- #167: Android capture constraints and frame gate are present, with Java helper tests and Flutter contract tests. A frame gate does not prove lower MediaProjection cadence or power use.
- #168: codec capability/policy code and fixtures are present. No device benchmark evidence was produced in this audit; hardware acceleration is not inferred from codec name.
- #169: calibrated adaptation policy and fake-clock tests are present. Runtime publisher integration/calibration and voice-under-video-pressure evidence remain separate gates.
- #170: server-owned descriptor API, Web metadata parser/publisher/presentation and Flutter receiver metadata are present in local master. Production deployment and paired Web/Flutter runtime remain unverified.

The pre-existing issue comments already specify the physical acceptance cases and redacted evidence format. Updated the stale local-branch statements in #166 and #167; updated #170 to record that its previously named Flutter commits are in local master and add this run's checks. No issue was closed.

## Checks run on this source tree

| Check | Result |
| --- | --- |
| `go test ./internal/media/publish_screen_descriptor/... ./internal/app/media_routes/screen_descriptor` | PASS, 4 Go packages; route composition has no direct tests |
| `npm test -- --run src/voice/screen_profile_metadata src/voice/livekit_screen_registry.spec.ts src/voice/livekit_screen_viewer_metadata.spec.ts src/voice/screen_share_setup_dialog.spec.ts src/voice/screen_receiver_panel.spec.ts` | PASS, 10 files / 36 tests |
| `npm test -- --run src/voice/screen_viewer_lifecycle.spec.ts src/voice/screen_adaptation src/voice/screen_profile` | PASS, 16 files / 56 tests |
| `python -m tools.verify.dependencies.dart` | PASS, 750 files |

Flutter unit/widget tests and Windows/macOS/Android builds: `NOT_RUN` because Flutter/Gradle are unavailable in this runner. Physical Android/Windows/macOS capture, paired viewer playback, resource/cadence/thermal measures, and production API/LiveKit verification: `NOT_RUN`.

For runtime evidence, use each issue's existing comment matrix. Record commit/build and SDK/SFU/device identity, actual counters and timing, scenario/repetition, voice outcome, and `PASS`/`FAIL`/`NOT_RUN` with a reason in sanitized JSON. Use null for unavailable measurements; do not substitute selected target values. Exclude IDs, credentials, SDP, user media, and hardware fingerprints.
