# Screen-share baseline harness

The page and Playwright test under `clients/web/tests/screen_profile/` use the pinned `livekit-client` SDK. They publish one video-only screen track and subscribe one remote viewer; they do not load BOOHTACORD production UI, profile guards, preview, or repair logic. Use an empty, isolated, non-production LiveKit room with short-lived publisher/viewer credentials created by the existing test operator workflow. No token endpoint is part of this harness.

## Automated moving-source run

From `clients/web` in PowerShell, set credentials only in the current process. Do not put tokens in command arguments, URLs, source files, logs, or issue attachments. Set the target acknowledgement only after independently verifying that the endpoint and image digest belong to the isolated test SFU:

```powershell
$env:SCREEN_BASELINE_TARGET = 'isolated-test'
$env:SCREEN_BASELINE_LIVEKIT_URL = 'wss://isolated-test-livekit.example'
$env:SCREEN_BASELINE_PUBLISHER_TOKEN = '<short-lived publisher token>'
$env:SCREEN_BASELINE_VIEWER_TOKEN = '<short-lived viewer token>'
$env:SCREEN_BASELINE_SOURCE_SHA = '<tested source commit SHA>'
$env:SCREEN_BASELINE_WORKTREE_STATE = 'clean or dirty, plus local diff identifier'
$env:SCREEN_BASELINE_SFU_IMAGE_DIGEST = 'sha256:<deployed test image digest>'
$env:SCREEN_BASELINE_DEVICE_PROFILE = '<OS, GPU/driver, power mode, display size/refresh>'
$env:SCREEN_BASELINE_REPEAT_INDEX = '60fps-r1'
npm run test:screen-profile
Remove-Item Env:SCREEN_BASELINE_TARGET,Env:SCREEN_BASELINE_LIVEKIT_URL,Env:SCREEN_BASELINE_PUBLISHER_TOKEN,Env:SCREEN_BASELINE_VIEWER_TOKEN,Env:SCREEN_BASELINE_SOURCE_SHA,Env:SCREEN_BASELINE_WORKTREE_STATE,Env:SCREEN_BASELINE_SFU_IMAGE_DIGEST,Env:SCREEN_BASELINE_DEVICE_PROFILE,Env:SCREEN_BASELINE_REPEAT_INDEX
```

The live test accepts only WSS or a loopback `ws://` endpoint and skips unless both short-lived tokens and the explicit isolated-target acknowledgement are present. The spec captures no screenshots, video, or Playwright traces. Its attachment is a numeric JSON result for that run; no credentials are part of the attachment. Repeat it five times in alternating order with the product client, setting a distinct repeat index for each run.

The fixed run uses the #157 catalog candidate `motion-1080p60-v1`: moving 1920×1080 source, VP8, a single layer, a 60 FPS target, and an 8,000,000 bit/s sender cap. The baseline overrides the product's normal simulcast policy to keep this comparison single-layer. It warms up for 30 seconds, records one-second windows for 180 seconds, and uses five repeats. Capture settings are configuration only. Encoded and decoded p05 FPS use counter deltas divided by monotonic elapsed time; missing, reset, hidden, or visibility-transition windows are unavailable and excluded. Source stats, RTP encode/decode/loss/jitter/time/bytes, selected candidate protocol/type/RTT/available bitrate, and presentation callback/frame-marker counts remain separated. Bitrate is `8 * delta(bytes) / delta(monotonicSeconds)`; receiver packet-loss ratio is `delta(packetsLost) / (delta(packetsLost) + delta(packetsReceived))` when both counters exist. Candidate IDs and addresses are never serialized.

For five live synthetic repeats, run `npx playwright test -c tests/screen_profile/playwright.config.ts tests/screen_profile/baseline.browser.spec.ts --repeat-each=5`; each attachment receives a distinct repeat suffix. For an intentional capture-rate control, open the local page in publisher and viewer roles, choose **30 FPS control** or **15 FPS control**, and keep every other condition fixed. The p05 calculation test verifies a 15 FPS counter series is reported as 15 rather than the 60 FPS baseline. The 20-cell visible frame marker has an 8-bit signature and a 12-bit rolling frame value; the viewer samples it in memory and exports only numeric IDs. Counter differences report repeated/skipped marker values. This verifies synthetic-source marker math; it does not establish physical display capture throughput. To test bandwidth limitation, apply a documented network shaper only on the isolated test network; compare the same metric report and note the shaping parameters. No bandwidth shaping or live 15 FPS SFU control was available during local verification.

Presentation metrics use `requestVideoFrameCallback` intervals and count callbacks per complete one-second window; `presentedFrameCallbackP05Fps` is a p05 callback rate, not unique-image or scanout proof. A callback gap over 500 ms is counted. `excessFreezeRatio` is `sum(max(gapMs - 500, 0)) / measuredWindowMs`. These callbacks and marker reads do not prove monitor scanout or end-to-end game latency. Static/background time is excluded from moving-source rate windows; no FPS or capacity SLO is asserted by the harness. Source-switch latency remains `null` because this harness does not switch sources.

## User-selected display capture

Start the local Vite server from `clients/web`:

```powershell
npm run dev -- --host 127.0.0.1 --port 4801 --strictPort
```

Open `http://127.0.0.1:4801/tests/screen_profile/baseline.html` in separate publisher and viewer pages. On both pages, confirm the isolated non-production target, enter the isolated WSS URL and each role's short-lived token, and connect. The publisher can start the numbered synthetic source or use **Start display capture** and select a real display/window in the browser chooser. In the viewer page, enable the numbered-source option only for the synthetic run; physical/unknown content is never treated as a generated frame counter. Download a numeric report from each role and pair the files by repeat index.

Fill in source SHA, test SFU image digest, SDK version (`npm ls livekit-client --depth=0`), and the device configuration fields. Record capture type, test room configuration, codec, source target, warm-up, window size, repeat/order, and any isolated network shaping. Do not include endpoint/room names, user identities, serials, tokens, SDP, IP addresses, device labels, audio, or pixels. Unknown fields should remain `unavailable` rather than being guessed.

## Comparison protocol and acceptance status

Compare the minimal client with the product client on the same device, SFU image, source, codec, one-layer topology, selected 60 FPS target, sender cap, and network. Alternate order across five repeats; use the same warm-up and measurement windows. Change one factor per follow-up run, then separately enable simulcast, the BOOHTACORD viewer, profile updates, or preview. Track source, encode, network, decode, and presentation metrics as separate stages. Proposed SLO values remain unvalidated experiments.

Local validation can test the harness calculations and existing Chromium encoder behavior. A live SFU comparison, physical display capture, constrained-network control, and hardware/driver acceptance require the isolated SFU and real devices. Record each as `NOT_RUN` until that evidence exists; do not infer a production cause from these local results.
