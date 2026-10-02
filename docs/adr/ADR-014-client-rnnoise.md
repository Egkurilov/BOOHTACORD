# ADR-014: Sender microphone RNNoise as an opt-in client engine

Date: 2026-10-02.
Status: implementation decision; acoustic and physical release gates remain open.

## Decision

Use a single pinned Xiph RNNoise v0.1 core and stock model in the Web WASM
worklet and native capture postprocessors. Keep the standard browser/native
WebRTC engine as the default. Requested engines are off, browser and rnnoise;
effective engine and failures are independent. Migrate legacy boolean true
to browser, false to off, missing/invalid values to browser. AEC and AGC stay
independent; microphone publish remains mono, high priority and 128000 bps.

Process only sender microphone PCM. Incoming voices and screen/game audio
never enter this processor. Go and LiveKit SFU/media transport remain unchanged.
No recordings, audio upload endpoints, custom VAD/AGC, new server telemetry
values, DeepFilterNet or inference service are added.

## Web ownership

A single microphone owner serializes capture, processor initialization, mode
change, mute, device replacement and recovery. Attach the public LiveKit
TrackProcessor before publication and retain original capture settings.
Invalidate generation immediately on leave/revoke; stale async results cannot
revive capture. Borrow the room AudioContext; never close it in processor
destroy. Processor owns its nodes and output track, not the input track.

RNNoise consumes mono 480-sample frames at 48 kHz in float S16 amplitude;
Web Audio normalization is converted exactly once. Preallocated bounded FIFO
adapts variable render quanta. Reset model/FIFO on transitions and emit silence
while muted. Reject a context rate other than 48 kHz. Do not require SAB or
cross-origin isolation, download from a CDN during calls, or grow memory in
the realtime callback. Assets are versioned same-origin release artifacts
with pinned source/model/WASM checksums and retained license metadata.

On DSP error attempt a bounded standard-engine fallback without losing the
requested preference. If recovery fails, keep microphone muted and show an
error. Unknown browser settings remain unknown. Diagnostics contain only
aggregated counters and engine state; never PCM, device labels or identities.

## Native feasibility and ordering

Pinned native SDKs expose mutable preencoder capture postprocessing:
Windows RTCAudioProcessing::SetCapturePostProcessing(CustomProcessing*),
Android AudioProcessingController.capturePostProcessing directByteBuffer,
and Apple AudioManager capturePostProcessingAdapter mutable RTCAudioBuffer.
These callbacks execute AFTER WebRTC AEC, NS and AGC stages. They do not permit
claiming AEC→RNNoise→AGC ordering. Browser processing similarly precedes the
worklet; user AGC settings are preserved. No native WebRTC rebuild is required
for the 48 kHz mono path. Changing hook order or adding unsupported buffer
formats would require a separate versioned SDK patch/build and evidence.

Keep a persistent native adapter and switch bypass atomically; pinned Windows
and Android wrappers have a null-detach hazard. PCM belongs to the callback
and is never retained or sent over MethodChannel. Native core and memory are
prepared outside callbacks. Enforce 480 frames, 48 kHz, mono; unsuitable formats
report fallback. Requested rnnoise is not reported effective until actual
frames were processed. Windows kCustom screen audio bypass remains intact.
Apple VPIO couples hardware AEC and NS in the pinned framework. Preserve AEC: RNNoise is explicitly unsupported on macOS/iOS with reason
`platform-aec-ns-coupled`, and the application restores the standard engine.
An independent hardware NS route or a software AEC policy requires separate
evidence and an ADR. Android disables hardware NS independently at the first
WebRTC factory initialization; standard software NS remains the default, while
existing hardware AEC and AGC policy stays unchanged. Hardware effects,
Bluetooth, background and power behavior still need physical acceptance.

## Validation and rollout

Separate unit/contract, actual browser graph/peer, synthetic signal and hardware
gates. Mock 100 transition cycles and deterministic fixtures are regression
evidence, not listening-quality or hardware AEC acceptance. Proposed p95
latency 30 ms and render p99 < 2 ms are targets pending baseline measurements.
Physical clean Russian speech, keyboard/fan/transients, double-talk, routes,
60-minute calls and 10/20 participants remain open until measured. No universal
CPU/FPS/quality/capacity promises follow from successful tests or builds.

RNNoise remains opt-in. VITE_RNNOISE_ENABLED is a build-time Web release flag,
not a live kill switch. Disabled flag hides the option and causes an explicit
fallback for saved rnnoise preferences. Switching default requires a later
ADR backed by listening and physical regression evidence. Signed release
assets include WASM/worklet/model provenance and SBOM component notices.

## Sources

- Owner supplied BOOHTACORD_RNNoise_Implementation_Plan.md, baseline 0bb11f7.
- [Xiph RNNoise](https://github.com/xiph/rnnoise/tree/cdf196b1e9de2f8ff1003328ebf9a4316477429d).
- [LiveKit2.22.3 public audio track](https://github.com/livekit/client-sdk-js/blob/v2.22.3/src/room/track/LocalAudioTrack.ts).
- [Pinned writable Windows processor](https://github.com/webrtc-sdk/libwebrtc/blob/libwebrtc.m150.7871.02/include/rtc_audio_processing.h).
- [Native APM ordering](https://github.com/webrtc-sdk/webrtc/blob/m150_release/modules/audio_processing/audio_processing_impl.cc).
