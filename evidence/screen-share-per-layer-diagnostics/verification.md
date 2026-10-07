# Screen-share per-layer diagnostics verification

- Date: 2026-10-07
- GitHub issue: #159
- Leaves: T-033 (Web), T-034 (Flutter)
- Base source revision: `e4cace80` (`origin/master` at worktree creation)
- Environment: Windows, Node.js 24.18.0, LiveKit JS 2.22.3

## Implemented in this packet

- Web sender snapshots are normalized per outbound row/RID, capped at eight
  rows per track and stored only in local diagnostics. Inactive and stale rows
  do not supply the selected dimensions or rates. Reset, unsupported, signed,
  zero-duration and missing intervals stay unavailable.
- FPS remains per layer. The SDK track bitrate remains the distinct total;
  layer bytes, retransmissions and packet loss are reported separately. The
  panel also shows available encode time per frame, quality limitation and
  NACK/PLI/FIR rates.
- Profile inspection, sender diagnostics and source/encode counters share a
  single in-flight/fresh sender stats sample with a 1-second minimum interval.
  The local diagnostics refresh runs at 1 second; report POST cadence stays at
  5 seconds. Cleanup clears the shared sample cache.
- Flutter retains a bounded in-memory layer snapshot per session, keys it by
  stream ID/RID, filters outgoing reports to the progressing selected layer,
  exposes layer and total bitrate separately, and clears both on stop. No
  report/API fields were added.

## Results

| Check | Result | Evidence |
|---|---|---|
| Web layer and shared-sampler tests | PASS | Focused Vitest tests cover active layers, multiple RID FPS, reset/stale/negative counters, stats dedupe and lifecycle clear. |
| Web complete client tests | PASS | `npm test`: 386 files and 1,193 tests passed after rebase (2026-10-07, Node.js 24.18.0). |
| Web TypeScript check | PASS | `npx vue-tsc --noEmit` exited 0 after the diagnostics source split (2026-10-07). |
| Flutter layer tests | NOT_RUN | `python -m tools.ci.native.flutter` exits because the required `flutter` executable is unavailable on this host. |
| SDK/SFU and two-client layer comparison | NOT_RUN | Requires isolated #158 credentials and runtime baseline. |
| Native capture/presentation, decoder/freeze, and collection-overhead acceptance | NOT_RUN | Requires platform callbacks/devices and measured before/after overhead. |

This is a sender-layer sampling slice, not completion of every #159 acceptance
item. The GitHub issue remains open.
