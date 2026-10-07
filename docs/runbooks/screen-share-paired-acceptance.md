# Screen-share paired device acceptance (#173)

This runbook joins real-device results for the current screen-share candidate. It is separate from #172 headless SDK/SFU correctness and from #158's minimal baseline. Use the existing isolated test deployment and both current product clients; do not use production for fault injection. A synthetic browser pass does not prove physical capture, display scanout, audio quality, or device support.

## Before pairing

1. Agree on the candidate SHA, both client builds, LiveKit server image digest, browser/SDK versions, device OS versions, GPU/driver, power mode, display dimensions and refresh rate. Use pseudonymous device classes; never record serials, hostnames, account IDs, room names, IPs, tokens, SDP, screenshots, pixels, audio, or message content.
2. Confirm each client is on the same isolated test room, then verify the capture chooser visibly identifies the intended app/window/display before consenting. If target identity is unclear, cancel and mark that run `BLOCKED`.
3. Use a moving source and a >=60 Hz display for 60 FPS cases. Warm up and measure using the same intervals as the approved #157 protocol; run each applicable case three times and compare with the #158 baseline. Alternate sender/receiver order between repeats. Record actual capture dimensions; requested settings are not measurements.
4. Keep real-game/video material local and non-sensitive. Use the synthetic frame-ID pattern for unique/duplicate/skipped counts, then separately inspect a game/video and fine text while scrolling for crop, color, stride, macroblocks and frozen regions.

## Required direction matrix

Run each applicable case in the machine-readable evidence template for these directions:

| ID | Sender → receiver |
|---|---|
| `win-chromium-to-win-chromium` | Windows Chromium → Windows Chromium |
| `win-chromium-to-macos-chromium` | Windows Chromium → macOS Chromium |
| `macos-chromium-to-win-chromium` | macOS Chromium → Windows Chromium |
| `chromium-to-safari` | Chromium → Safari |
| `flutter-win-to-web`, `flutter-macos-to-web` | Flutter Windows/macOS → Web |
| `web-to-flutter-win`, `web-to-flutter-macos` | Web → Flutter Windows/macOS |
| `android-physical-to-macos`, `android-physical-to-web` | Physical Android → macOS/Web |
| `web-to-android-physical`, `web-to-ios` | Web → physical Android/iOS receiver |

For each direction, cover the four moving profiles 720p30/60 and 1080p30/60; text at 15 FPS plus a 15→30→15 transition; game/video; fine text and scroll; and every available full-display, window and tab capture mode. Mark 1440p60 optional until its capability is approved. For every applicable direction, also run 100 source/profile switches, restart/reconnect and sleep/background/resume, voice plus screen-audio listening, and controlled degraded-network downgrade/recovery. Unsupported platform behavior is `UNSUPPORTED` only when a contract or platform capability reference proves it; record case-level exceptions in `unsupportedCases`. Unavailable hardware is `NOT_RUN`.

## Measurements and decisions

Record source/capture, encoded, decoded and presented FPS separately; frame-ID uniqueness/duplicates/skips; freeze count and duration; first-frame and switch p95; encode/decode p95; packet loss, RTT, jitter, codec and active layer. Null means unavailable, never zero. Measure glass-to-glass latency only with a validated shared clock or external synchronized instrument and report uncertainty. Do not subtract unsynchronized client clocks.

An individual case passes only against the thresholds approved in #157 for that declared configuration. A peak FPS or settings label is not proof of sustained FPS. Inspect failures by source, encode, network, decode or presentation stage; preserve each repeat and link a defect plus retest rather than averaging failures away. Voice must remain usable during recovery; test mute/deafen/PTT, 0/50/100% and supported gain above 100%, late audio track and double-talk/echo. Do not claim system audio where the client does not publish it.

## Evidence and execution

Copy `evidence/media/issue-173-paired-acceptance-2026-10-07.json`, fill only approved fields, and keep unknown numeric samples `null`. The verifier rejects unexpected fields to keep private content out of committed evidence:

```powershell
python -m unittest tools.verify.paired_screen_acceptance.test_evidence
python -m tools.verify.paired_screen_acceptance.validate_evidence evidence/media/issue-173-paired-acceptance-2026-10-07.json
```

The current record is deliberately `NOT_RUN`: this checkout has no paired hardware run attached. A `PASS` report requires a candidate source SHA, LiveKit image digest, three measured repeats and non-null required metrics for every case on each applicable direction, and no required `NOT_RUN`, `BLOCKED` or `FAIL`. Report environment and limitations with the numeric evidence; do not attach recordings or raw diagnostics containing user/network identifiers. Map relevant evidence back to #55/#57/#131/#132/#62 without closing those wider QA issues automatically.
