# Issue #162 — screen preview subscriptions

## Change

- Screen shares remain discoverable from publication metadata, with the existing avatar/initials fallback when no thumbnail is available.
- Web no longer subscribes to unselected screen video to capture detached thumbnails. Selecting a screen continues to subscribe to its video/audio; microphone playback and screen discovery remain active.
- Flutter removed the temporary preview subscription queue. Automatic remote subscription is microphone-only; selected screen video/audio behavior is preserved.
- Flutter thumbnail capture is gated by active room, participant, publication, selected identity, and a selection revision checked across async work. Publication-aware cleanup prevents an old unpublish event from deleting a replacement thumbnail.
- No real-frame evidence or reference assets were added. Issue #140 deadline repair was not changed.

## Checks

- Web focused tests: PASS — 5 files, 20 tests.
- Full Web tests: PASS — 387 files, 1,190 tests.
- Web production build: PASS (`vue-tsc` and Vite). Existing warnings: LiveKit is both statically and dynamically imported; one minified chunk exceeds 500 kB.
- `git diff --check`: PASS.
- Dart dependency boundary check: PASS (`python -m tools.verify.dependencies.dart`, 672 files).

## Acceptance not run

- Flutter tests/analyzer: NOT_RUN — Dart and Flutter SDKs are unavailable in this environment.
- Physical-device validation, LiveKit/SFU subscription counters, 20-publication room, reconnect/stop lifecycle, and #158 pre/post harness: NOT_RUN. No live SDK/SFU validation was attempted.
