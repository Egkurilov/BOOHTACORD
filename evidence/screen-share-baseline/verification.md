# Screen-share baseline harness verification

- Date: 2026-10-07
- GitHub issue: #158
- Leaf: T-032
- Base source revision: `7d578021` (`origin/master` at worktree creation)
- Environment: Windows, Node.js 24.18.0, `livekit-client` 2.22.3
- Profile: #157 catalog candidate `motion-1080p60-v1`; one VP8 layer at an 8 Mbit/s cap. This is a test intent, not validated capacity evidence.
- Measurement plan: 30-second warm-up, 180-second run, one-second windows, five repeats.

## Results

| Check | Result | Evidence |
|---|---|---|
| Baseline harness TypeScript | PASS | Strict `tsc --noEmit` over the baseline page, browser specs, and baseline modules, including the catalog JSON import. |
| Web screen-profile suite | 7 PASS, 1 SKIPPED | `npm run test:screen-profile` — page safety, marker encoding, metrics, stats sanitization, and Chromium encoder checks passed. The live-SFU run skipped because isolated credentials and target confirmation were not provided. |
| Web production build | PASS | `npm run build` (`vue-tsc --noEmit && vite build`). Existing Vite warnings remain for LiveKit mixed dynamic/static imports and a minified bundle over 500 kB. |
| LiveKit/SFU synthetic baseline | NOT_RUN | No isolated server credentials/image digest were supplied. |
| Physical display capture comparison | NOT_RUN | Requires a user-selected display and recorded device/driver details. |
| Isolated bandwidth shaping and hardware/driver acceptance | NOT_RUN | Requires the isolated lab network and target devices. |

The browser test requires both isolated short-lived tokens and `SCREEN_BASELINE_TARGET=isolated-test`; its endpoint check accepts WSS or loopback only. No production endpoint was contacted. The skipped run is not a baseline measurement and does not pass an FPS or capacity gate. Numeric reports exclude pixels, SDP, candidate identifiers/addresses, endpoint names, and credentials.
