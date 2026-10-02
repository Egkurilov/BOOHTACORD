# RNNoise implementation and automated verification

```yaml
status: PARTIAL
repository_sha: 0bb11f7c2c6de01efa77d1d7a60a36f1f83a5399
implementation_sha: null
source_scope: pre-commit implementation worktree; release record binds the final commit separately
rnnoise_commit: cdf196b1e9de2f8ff1003328ebf9a4316477429d
model_sha256: f0cdb52b30501aab489f90fedbc7a023c719d91b337db2da7f26fc3036556b95
wasm_sha256: c9e99c9a9b04c8a9f048f3961f95657c3d0b21cf6280d1d518dbf63aeedd1604
platform: macOS ARM64 host; actual Chromium browser and native synthetic harnesses
browser_or_native_build: Chromium 153.0.8010.12; Flutter 3.47.5; Dart 3.13.4; Emscripten 4.0.20
hardware: NOT_RUN
microphone_and_output_route: authored synthetic source only; no physical capture or recordings
requested_mode: rnnoise
effective_mode: rnnoise in actual Web graph and LiveKit transmission; native hardware not verified
release_readiness: NO_GO for acoustic acceptance or changing the default
```

## Confirmed automated results

- Web: 759 tests passed; TypeScript check and production Vite build passed.
- Flutter app: 404 passed. Vendored LiveKit: 433 passed, one skipped.
  Vendored flutter_webrtc: 18 passed. Shared native gate analyzer: no issues.
- Tools: 85 Python tests passed. Contracts, requirement traceability, workflow
  routing, component boundaries and documentation links passed. The Windows
  approved product brief is unavailable on this Mac; traceability validates the
  committed requirement index, not a fresh comparison against that brief.
- Pinned local Emscripten and digest-pinned compiler container independently
  produced identical WASM bytes. The scalar module has no imports or memory
  growth. A 140-frame real-WASM test passed finite PCM, silence and reset checks.
- Five actual Chromium tests passed: scalar AudioWorklet under same-origin CSP,
  processor error/mute/reset, malformed/404 assets and rate rejection, 100 real
  graph teardowns preserving borrowed source/context, direct WebRTC receiver,
  and two isolated browser contexts through actual LiveKit 1.13.7.
- The LiveKit test uses public `LocalAudioTrack.setProcessor`, microphone
  publication at 128000 bps/high priority/mono, and receiver aggregate PCM
  measurement. Receiver output became silent after mute. Sources are synthetic;
  physical microphone and listening quality are NOT_RUN.
- Nginx 1.27.4 served the exact model/WASM checksums, application/wasm MIME,
  distribution notice and component CycloneDX SBOM. Missing versioned audio
  returned 404; ordinary SPA routes remained available.
- Native core processing/bypass/reset/invalid format/OOM, actual JNI direct
  buffers on the host JVM, sanitizer adapter checks, actual Apple framework
  compilation and shared Swift-core build passed. These are not Android or
  Windows device acceptance. Target distribution results belong in the release
  record after hosted builds complete.
- Actual Flutter macOS release build passed for ARM64 and x86_64, with strict
  codesign verification. The executable SHA-256 was
  `ac318a3b6d568d34a2ce2c602bed589b96a8db372d13c0e0617e5f3cce2070b4`.
  An isolated build directory avoided Documents/Finder generated metadata;
  source metadata was not modified. This proves compilation and signature
  integrity, not physical media acceptance or Apple RNNoise availability.
- A native LiveKit recapture regression was fixed: a muted replacement track
  is disabled before sender replacement. The regression failed before the fix
  and passed afterward, including standard-engine rollback.

The synthetic quality harness processes 144000 samples per signal. Its measured
stationary-noise RMS ratio was -6.5169 dB, correlation lag 479 samples (9.98 ms),
and Node frame CPU p99 0.1114 ms in this run. These values describe authored
synthetic signals and this host. They do not prove speech quality, browser
render callback p99, physical latency or minimum-device performance.

## Native capabilities

Android disables hardware NS independently at the first WebRTC initialization;
existing AEC/AGC policy is preserved. The default standard software NS and
Windows recapture/rollback remain available. Android and Windows RNNoise require
actual 48 kHz mono 480-frame writable PCM; unsuitable formats report unknown
and restore the standard engine. Recovery failure leaves capture muted.

Apple SDK VPIO couples hardware AEC and NS. macOS/iOS explicitly report
`platform-aec-ns-coupled`, preserve AEC and use the standard fallback. Writable
hook existence and a compiled model do not establish a usable Apple RNNoise
mode. Independent hardware NS or a different AEC policy needs further evidence
and an ADR.

## Open acceptance matrix

| Plan scenarios | Result and remaining evidence |
|---|---|
| 1–4: Russian speech, fan, keyboard and transient sounds | NOT_RUN: aligned listening and real speech corpus |
| 5: physical AEC and double-talk | NOT_RUN: physical speaker/microphone comparison |
| 6: PTT/mute/deafen and buffered fragments | Synthetic receiver and lifecycle tests PASS; physical PTT/deafen NOT_RUN |
| 7: USB/Bluetooth/device/rate/route | Mock ownership and rate rejection PASS; physical routes NOT_RUN |
| 8: reconnect/permissions/leave during preparation | Lifecycle generation and cleanup tests PASS; physical reconnect NOT_RUN |
| 9: 404/HTML/CSP/processor error/CPU pressure | Actual asset/processor/CSP-compatible graph tests PASS; CSP-denied fallback is covered by rejection/unit path, hardware CPU pressure NOT_RUN |
| 10: voice + 1080p60 screen/system audio | Source bypass preserved; physical comparison/FPS NOT_RUN |
| 60-minute resource/latency run | NOT_RUN |
| 10/20 real senders; optional 30 stress | NOT_RUN; no capacity claim |
| Browser callback p99 < 2 ms; added latency p95 ≤ 30 ms | NOT_RUN on minimum hardware; Node synthetic figures are not these gates |
| Blind clean-speech/listener improvement | NOT_RUN; this gate remains open |

The first release stays experimental and opt-in; standard processing remains
the default. `VITE_RNNOISE_ENABLED=false` hides the Web offer in a rebuilt
release and explicitly falls back for a saved request. It is a build-time
control, not a runtime kill switch. DeepFilterNet is deferred research.
