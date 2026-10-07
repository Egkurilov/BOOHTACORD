# Issue 159 collection correctness — 2026-10-07

Source base: `319fa06ce219e493f10d43b1fb54ff732f1b4d34`; branch `codex/issue-159-media-sample-correctness`.
Native packet: `split_first`, backlog T-033/T-034, dependencies T-031/T-032.

## Implemented and observed

- Web and Flutter sender windows separate late/signed loss correction from actual frame/byte resets. RID/SSRC/track changes, inactive/reactivated encodings, zero/repeated timestamps and >10s windows cannot produce invented rates. Frame FPS is never summed across layers.
- Remote-inbound is paired to outbound with identity/SSRC guards; audio is excluded. Selected layer and total outgoing bytes have distinct names; totals require common end timestamps and interval duration across observed video layers. Missing rows/counters do not become zero.
- Actual encode time, retransmitted bytes, NACK/PLI/FIR and quality limitation counters are read from raw SDK reports when supported. Flutter framesSent fallback remains explicitly `sent` in local diagnostics; encoded_fps is exported only from actual framesEncoded. Quality-limitation durations remain bounded-key private local SDK counters (seconds), not metric labels.
- Raw receiver snapshots retain stream/SSRC, decode counters, drops, totalDecodeTime, jitterBufferDelay/emittedCount, feedback counters, and SDK freeze count/total duration. RTX-only, absent decoded counters and ambiguous multiple primary inbound rows return unavailable. Duration-per-frame uses unrounded counter deltas; reset/stream changes and stale windows invalidate rates.
- Real Web requestVideoFrameCallback first callback elapsed time traverses mounted Vue hooks into the authenticated API report. It starts at observation/selection setup, not publisher capture or network admission. Duplicate compositor counters contribute no additional FPS; counter reset starts a new interval. Compositor progress is not proof of unique images.
- Native framesRendered/texture counters no longer claim presentation or monitor scanout; presentation_source=unsupported and presented_fps absent. Native capture/renderer hardware callbacks beyond existing SDK counters remain unsupported.
- Existing single sender/controller pollers now share bounded 1s caches and in-flight SDK requests. Logical 2s timeout never creates a concurrent getStats call on the same sender/receiver. stop/dispose clears cache and generation; late completion cannot restore cleared cache or old UI state. Receiver selection, stop/logout/revoke retain existing session/generation guards.
- Optional interval/provenance fields reach typed report, OpenAPI, server validation, canonical generated flow allowlist and client relay spans. Span chunks reserve one attribute for trusted relay account enrichment; total output stays <=32. HTTP body remains <=2KiB; identities/content never enter anonymous numeric reports. Legacy fields remain accepted without fabricated new fields. Existing #6 exporter is reused.
- collection_state records active/inactive/unknown/stale/unavailable and SDK mute/hidden where directly known. Low FPS does not infer network failure. Subscriber/source motion or reconnect context without direct SDK evidence stays unknown rather than fabricated.

## Native checks

- Web final full Vitest: **410 files / 1281 tests PASS**, 0 skipped. Earlier failing tests reproduced signed-loss reset and inactive-reactivation errors before implementation.
- Web production `vue-tsc --noEmit && vite build`: PASS, `VITE_PUBLIC_ORIGIN=https://boohtacord.example` (local validation only). Existing bundle-size/dynamic-import warnings remain.
- Flutter 3.47.5 / Dart 3.13.4, locked package resolution PASS. Full application suite: **795 PASS / 1 pre-existing SKIP / 0 failed**. Regression discovered SDK sender getter on disposed/mock track during stop; cleanup now uses stored poller and full suite re-run PASS. Last native encoded-counter/provenance extension focused SDK/parser tests PASS.
- Flutter analyze `--no-pub --no-fatal-infos`: PASS (0 errors/warnings; existing informational lints, 54 total in recorded run). No platform distribution build performed.
- `python -m tools.ci.native.contracts`: PASS: 194 Python tests (1 pre-existing SKIP), 19 OpenAPI source/parity checks, schema 3.1 / 89 public operations / 3 private exclusions; Dart boundary/import checker, docs links, traceability 39 requirements, CI/signing/SBOM checks PASS.
- Server API/measurement/relay/native HTTP packages and privacy/legacy rejection tests: PASS, recorded in `evidence/observability/issue-159-report-contract-2026-10-07.json`; integrator adds final combined results.
- `git diff --check`: PASS. New collection leaves <=120 source lines; Flutter legacy UI remains existing oversized code, numeric sampling/math physically extracted to receiver_metrics leaf.

## Physical acceptance

**NOT_RUN**: paired physical sender/viewer layer correspondence, capture/renderer native callback provenance across real supported devices, moving/static content and transport scenarios, and before/after real getStats CPU/battery overhead budget. SDK-shape fixtures are not physical hardware proof. No deployment, release build, issue closure, new media exporter, source-image changes or production mutation in this packet.
