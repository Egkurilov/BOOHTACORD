# Screen-share per-layer diagnostics verification

- Date: 2026-10-07
- GitHub issue: #159
- Leaves: T-033 (Web), T-034 (Flutter)
- Base source revision: `7d578021` (`origin/master` at worktree creation)
- Environment: Windows, Node.js 24.18.0, LiveKit JS 2.22.3

## Implemented in this packet

- Web sender snapshots are normalized per outbound row/SSRC/RID, capped at
  eight rows per track and stored only in local diagnostics. A row becomes
  active only when encoded-frame counters advance; byte-only progress and stale
  dimensions cannot select a layer. Counter resets invalidate the whole window.
- FPS remains per layer. The SDK track bitrate remains the distinct total;
  layer bytes, retransmissions and packet loss are reported separately. The
  panel also shows available encode time per frame, quality limitation and
  NACK/PLI/FIR rates.
- Web remote-inbound loss and RTT are paired to their outbound row through
  `localId`; Flutter pairs them through the outbound `remoteId`. Flutter reads
  one raw sender stats report inside the existing gated 1-second session
  sampler and bounds mapped outbound layers to eight, preserving SSRC without
  modifying the vendored SDK.
- Flutter encoded FPS is computed from frame-counter deltas. It no longer uses
  the SDK's instantaneous FPS when there is no valid interval. IDs stay in
  process-local diagnostic state; no metric/API fields were added.
- Profile inspection, sender diagnostics and source/encode counters share a
  single in-flight/fresh sender stats sample with a 1-second minimum interval.
  The local diagnostics refresh runs at 1 second; report POST cadence stays at
  5 seconds. Cleanup clears the shared sample cache.
- Flutter retains a bounded in-memory layer snapshot per session, keys it by
  stream ID/SSRC/RID, filters outgoing reports to the progressing selected layer,
  exposes layer and total bitrate separately, and clears both on stop. No
  report/API fields were added.

## Results

| Check | Result | Evidence |
|---|---|---|
| Web focused layer, sender and poller tests | PASS | 10 focused tests passed, including SSRC rotation, frozen layers, whole-window reset, remote-inbound association, shared sampling and cleanup. |
| Web complete client tests | PASS | `npm test`: 386 files and 1,196 tests passed (2026-10-07, Node.js 24.18.0). |
| Web TypeScript and production build | PASS | `npm run build` passed `vue-tsc --noEmit` and Vite build (2026-10-07). |
| Dart dependency boundary | PASS | `python -m tools.verify.dependencies.dart`: 670 files. |
| Flutter focused and complete tests / formatter | NOT_RUN | `python -m tools.ci.native.flutter` and `dart format` cannot start because `flutter`/`dart` executables are unavailable on this host. A Flutter raw-stats fixture test was added for CI. |
| SDK/SFU and two-client layer comparison | NOT_RUN | Requires isolated #158 credentials and runtime baseline. |
| Native capture/presentation provenance, decoder/freeze counters, and collection-overhead acceptance | NOT_RUN | Requires supported platform callbacks/devices and measured before/after overhead. These remain explicit follow-up acceptance gaps. |

This change corrects sender-layer samples in Web and Flutter. It does not claim
device acceptance or support for native capture/presentation callbacks that
the current SDK does not expose. The GitHub issue remains open until Flutter
CI and the physical/two-client acceptance rows pass.
