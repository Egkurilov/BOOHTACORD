# Issue #110: voice audio parity

Operating brief: split_first; exact leaves are voice/audio_profile,
voice/audio_diagnostics, Flutter voice/audio_profile and audio_diagnostics,
observability/ingest_client_traces/voice_audio, tools/audio/voice_parity.
Preserve 128000 until measured A/B supports an ADR change. Preserve AGC/AEC/NS,
PTT, device switching, serialized recovery, media ownership and server ACL.
New files target 100/hard 120 lines; no recordings, identifiers or levels exported.

1. Add focused tests for the shared profile, delta/reset/codec stats, microphone
   scoping, disposal, native constraints and telemetry sanitization before code.
2. Define versioned JSON source and deterministic checked-in Web/Dart adapters.
   Pin profile to each room. Offer 64/96/128 only before joining; retain 128 default.
   Explicit DTX/RED/high priority and best-effort mono/48k capture in both clients.
3. Read microphone sender and subscribed microphone receiver RTC stats. Calculate
   interval bitrates/loss/concealment; distinguish RTP codec channels from capture
   channels, requested flags from negotiated flags, and missing stats from zeros.
   Reset on track/room changes and suppress late completions after leave/reconnect.
4. Expose actual diagnostics in audio settings on Web/Flutter. Export a whitelist
   only; levels remain local. Send bounded, quantized voice.audio.sample spans
   through the existing authenticated, sanitized OTLP relay.
5. Supply blinded trial preparation and a four-direction, three-loss-level,
   DSP/isolation procedure. Record NOT_RUN for physical/listener acceptance.
6. Inspect source diff, status and sizes. Commit/push/merge with [skip ci].

Owner direction defers tests, native checks, builds and deployment to the grouped
run. Tests are written now but not executed. Issue remains open pending hardware
and blind A/B evidence; implementation constants cannot prove equivalent sound.
