# Synthetic audio browser gate

Run from `clients/web` after installing dependencies and building pinned assets:

```sh
npm run test:audio:browser
npm run test:audio:quality
```

Install the pinned Playwright Chromium beforehand. `CHROMIUM_EXECUTABLE_PATH`
may select an existing Chromium for a local run; the actual browser version is
printed in the PASS receipt. The browser runner starts an isolated localhost
Vite fixture on port 4800 with a CSP that permits same-origin modules and WASM.
It exposes test-only malformed/missing asset routes and does not capture a real
microphone, record audio, upload PCM or call production services.

The LiveKit case requires a disposable local dev SFU at
`ws://127.0.0.1:17880`. CI owns its startup/cleanup. Use pinned LiveKit 1.13.7 image
`sha256:6fd3b7088874c4d119160dd688798dfec852bc014786d392caad15f6f63912a3`.
Map WebSocket 17880:7880, UDP 7882:7882, and TCP 17881:17881 when passing
`--rtc.tcp_port 17881`. The fixture SDK issues short-lived development tokens
in memory with `no-store` responses; no token appears in test receipts.

Five actual browser tests cover the scalar WASM/AudioWorklet graph, nonfinite
and clipping guards, mute/unmute model/FIFO reset, a genuinely throwing worklet
and immediate output silence, CSP and MIME, HTML/404/model rejection, real 44.1
kHz mismatch, 100 graph teardown cycles preserving borrowed capture/context,
a direct WebRTC peer pair, and two isolated browser sessions through LiveKit.
The LiveKit sender uses the public `LocalAudioTrack.setProcessor` API and the
normal microphone source/publish options. The receiver checks aggregate PCM
energy after attaching its remote audio track for Chromium playout.

Variable quantum sample accounting is also verified in browser; exhaustive
frame conversion and reordering tests run in Vitest. These gates use an
oscillator or authored synthetic PCM. They prove integration and bounded
resource ownership, not physical device behavior or perceived improvement.
Clean Russian speech, browser capture NS comparison, physical AEC/double-talk,
Bluetooth/background behavior, long hardware calls, render callback p99 and
10/20 real participant load remain separate evidence gates.
