# Screen-share baseline harness

The harness under `clients/web/tests/screen_profile/baseline/` is test-only. It uses the pinned `livekit-client`, creates one screen-video publisher and one remote viewer, and does not use BOOHTACORD production UI, preview, profile guard, or repair logic. The automated source is a moving, numbered canvas at 1920×1080; the local page also offers a user-triggered `getDisplayMedia` source for device comparisons.

## Automated synthetic baseline

Create two short-lived credentials in the isolated test environment for the same non-production room: a publisher token with screen-video publish permission and a different viewer token with subscribe permission. Keep both tokens out of source files, shell transcripts, test reports, URLs, and artifacts. The test passes them through environment variables and the local page clears its password input after use. No token-minting endpoint is included.

From `clients/web` in PowerShell:

```powershell
$env:SCREEN_BASELINE_LIVEKIT_URL = 'wss://isolated-test-livekit.example'
$env:SCREEN_BASELINE_PUBLISHER_TOKEN = '<short-lived publisher token>'
$env:SCREEN_BASELINE_VIEWER_TOKEN = '<short-lived viewer token>'
$env:SCREEN_BASELINE_SOURCE_SHA = '<tested source commit SHA>'
$env:SCREEN_BASELINE_WORKTREE_STATE = 'clean or dirty, plus local diff identifier'
$env:SCREEN_BASELINE_SFU_IMAGE_DIGEST = 'sha256:<deployed test image digest>'
npm run test:screen-profile
Remove-Item Env:SCREEN_BASELINE_LIVEKIT_URL,Env:SCREEN_BASELINE_PUBLISHER_TOKEN,Env:SCREEN_BASELINE_VIEWER_TOKEN,Env:SCREEN_BASELINE_SOURCE_SHA,Env:SCREEN_BASELINE_WORKTREE_STATE,Env:SCREEN_BASELINE_SFU_IMAGE_DIGEST
```

The baseline test can be repeated five times without running the other browser test:

```powershell
npx playwright test -c tests/screen_profile/playwright.config.ts tests/screen_profile/baseline.browser.spec.ts --repeat-each=5
```

The run uses VP8, one layer, a selected 1080p60 target capped at 8,000,000 bit/s, one-second samples after a five-second warm-up, and a ten-second measurement window. The report attachment contains SDK and browser versions, source/deployment identity fields, sanitized sender stats, synthetic draw counts, first-frame latency, receiver presentation callbacks, and visibility state. It contains no tokens, SDP, addresses, track/session IDs, device labels, audio, or captured frames. Missing stats stay missing; they are not replaced with zero.

The derived encoded FPS is `delta(framesEncoded) / delta(monotonicSeconds)` and bitrate is `8 * delta(bytesSent) / delta(monotonicSeconds)`. p05 is calculated over visible one-second encoded-FPS windows. Presentation callback gaps over 500 ms are a browser-observation proxy, not proof of a unique image freeze or monitor scanout. `getSettings().frameRate` is reported only as a capture setting. The harness records measurements and makes no 55 FPS, 2 second, or capacity acceptance claim.

## Physical display-capture comparison

Start the existing local Vite server from `clients/web`:

```powershell
npm run dev -- --host 127.0.0.1 --port 4801 --strictPort
```

Open `http://127.0.0.1:4801/tests/screen_profile/baseline.html` in two browser pages. Set one to publisher and one to viewer; enter short-lived tokens from the same isolated room. Connect the viewer, connect the publisher, then use **Start display capture** and choose an actual display or window in the browser prompt. Use **Download 10-second numeric sample** after capture has begun. The browser OS chooser is a user action; automation does not impersonate it.

For a paired comparison, record source SHA and dirty state, test SFU image digest, LiveKit SDK/browser/OS versions, CPU architecture, GPU/driver, display resolution/refresh rate, power mode, capture type, codec, source profile, sample windows, warm-up, repeats, and exclusions. Change one factor at a time and alternate run order. Do not include endpoint names, serials, tokens, SDP, IP addresses, or media. If hardware or server details are unavailable, record `NOT_RUN`/`unavailable` and keep the proposed SLO unproven.
