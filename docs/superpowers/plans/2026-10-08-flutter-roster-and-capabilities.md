# Flutter roster recovery and screen capability implementation plan

**Goal:** Finish Flutter source scope of #270 and #85 while preserving voice admission and capture lifecycle.
**Architecture:** Keep roster HTTP-only with one session-scoped SSE generation and independent GET revision. Split the existing setup dialog into source inventory, quality selection, layout and capability leaves, preserving external API and native source IDs.
**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, HTTP, native WebRTC/LiveKit.

Operating brief: split_first; routes=voice/roster_state and screen/setup; hard120 production lines; scoped native edges=app/media_access/voice_roster.dart, widgets/screen_share_setup_dialog.dart and exact workspace preview binding. Baseline=single HTTP SSE, fixed2s retry, stale10s, native video-only, permission occurs after dialog acceptance. Unknown hardware capability remains conditional. Stop condition=meaningful native tests/analyze, preservation of manual Join and no media side effects, all newly owned executable files <=120.

- [ ] Add explicit roster phase and injectable timer/jitter; separate refresh operation from stream generation; retain last successful snapshot only while stale timer remains.
- [ ] Tests: 503 retry/recovery, malformed SSE, 401/revocation, successful empty, stop/account switch/dispose cancellation and retry budget/manual restart. Use deterministic timer scheduler; no sleep-dependent backoff tests.
- [ ] Implement roster unavailable events and terminal session-expired; bounded exponential backoff/jitter and manual retry closing old stream before starting replacement.
- [ ] Bind error/retry UI through existing roster preview composition; extract owned preview/member presentation if aggregate binding is unavoidable.
- [ ] Split setup dialog completely into <=120-line native leaves (source inventory controller, source grid/card, quality option/picker, footer/header, mobile/capability notice and dialog layout).
- [ ] Add pre-picker platform capability model: native viewer supported, capture subject to source availability/OS permission, native audio never published; unsupported capture leaves voice/viewer available. Cancel dialog returns null.
- [ ] Test each supported native platform notice, unsupported capture, source errors/late generation and dialog cancellation at mobile/desktop widths. Run Flutter tests and analyze with installed runtime.
- [ ] Inspect diff/status/file sizes and commit only source, tests and plan. Device QA remains separately evidenced.
