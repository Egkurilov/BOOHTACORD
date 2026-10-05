# ADR-016: versioned voice profile and measured parity gate

Date: 2026-10-05. Status: implementation; acoustic promotion NOT_RUN.
Refs: #110, ADR-014, ADR-015, REQ-AUDIO-01.

## Decision

The canonical source is contracts/voice-audio-profile.json. Generate checked-in
Web, Dart and relay whitelist adapters with tools/audio/voice_parity/generate_profiles.py.
Unit tests compare generated adapters with the canonical JSON.

The active default stays baseline-128-v1: mono request, 48k ideal capture,
128000 bps cap, high encoding priority, DTX and RED enabled. SDK negotiation,
network adaptation and platform support can produce different actual results.
Opus RTP channels=2 alone does not establish stereo capture. FEC, stereo and DTX
fmtp are negotiated declarations, not proof that every packet uses that feature.
Unreported properties remain unknown.
An Opus codec stats entry does not establish that RED is disabled. Report RED
as true only when explicitly reported; otherwise keep it unknown. The isolated
2026-10-05 browser comparison measured 130.8 vs 64.4 kbit/s with RED on/off at
the same 64k encoder cap. This explains measured payload overhead in that setup,
not a perceptual preference. See the issue-110 completion evidence and anonymous
measurements in evidence/; default promotion remains NOT_RUN.

The vendored Flutter SDK inverted its positive red option when setting the SFU
disableRed field (red=true sent disableRed=true). Correct the polarity while
preserving encrypted-room RED disabling. This is a concrete publication mismatch;
its perceptual effect still requires physical comparison.

Windows GetStats previously fell back to all-PC stats when a requested remote
track was absent from the capture registry. Resolve nonempty selectors through
the PC sender/receiver lists or return Track not found, matching Android/Apple.
An unscoped PC stats request remains supported for connection RTT.

speech-64-v1 and speech-96-v1 are session-local A/B candidates. Select before
joining; a room retains its selected cap through mic replacement and reconnect.
Neither candidate is promoted or described as superior. Promotion requires the
physical four-direction comparison, blinded speech ratings, silence/speech RTP
measurements, clean/1%/3% loss and an ADR amendment recording those results.

AGC, AEC, standard/off/RNNoise, saved devices, VAD/PTT, manual gain and capture
ownership remain under the existing user preferences and lifecycle. Native ideal
format constraints cannot force hardware/driver support. Native getSettings can
echo requested constraints, so original capture/DSP confirmation stays unknown.
The existing native hook can expose its last initialized PCM format separately.
It does not prove hardware capture format or perceptual quality.

## Diagnostics and privacy

Read track-scoped microphone sender and subscribed microphone receiver stats.
Never use screen/game audio counters. Monotonic local time and interval counter
deltas give payload bitrate, packets, loss and concealment; jitter is seconds→ms.
Duplicate, reset, replaced, missing or stale counters yield unknown rates.
Reset history on reconnect, dispose polling on leave, suppress late results.
RTP payload bitrate includes redundant/retransmitted payload and is not an encoder
cap or link bandwidth. RTP header/padding and transport headers are excluded from
these counters; see [WebRTC Stats](https://www.w3.org/TR/webrtc-stats/).

UI reports are anonymous. Audio levels stay local and are stripped from export.
The authenticated OTLP relay accepts voice.audio.sample with a closed profile/
platform/codec vocabulary and quantized bitrate/jitter/loss/concealment attributes.
At most one sender and worst-loss receiver sample per ten seconds are exported.
No PCM, message content, device labels, participant/track/SSRC IDs or precise
levels are sent. Unsupported stats do not fail microphone controls.

Android/iOS use the same Flutter profile implementation. ADR-014 native RNNoise/
AEC/NS fallback restrictions remain binding. Go does not process audio payloads.
