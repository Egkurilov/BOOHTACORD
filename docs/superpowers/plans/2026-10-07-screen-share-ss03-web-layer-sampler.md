# SS-03 Web per-layer sender sampler

## Route

Leaf: `clients/web/src/voice/screen_livekit_diagnostics`.

## Packet

Normalize bounded outbound RTP rows by publication track and RID/SSRC. Derive
interval FPS, sender bytes, retransmitted bytes and remote loss per active row;
do not sum FPS across rows. Keep LiveKit's track bitrate as a separate total.
Use one 1-second sender stats sampler shared with profile inspection. Keep
diagnostic IDs local and avoid changing the reporting API.

## Files

- `screen_sender_layers.ts` and focused layer fixtures.
- `screen_stats_sampler.ts` and lifecycle tests.
- `screen_livekit_diagnostics.ts`, `screen_diagnostics.ts`,
  `ScreenDiagnosticsPanel.vue`.
- `viewer_diagnosis/capture.ts` and focused active-layer regression.

## Validation

Run the Web Vitest suite and `vue-tsc --noEmit`. Runtime/SFU results require
the isolated #158 baseline environment and remain separate evidence.

## Stop condition

This packet covers sender-layer intervals, activity selection and shared stats
sampling. Decode, renderer callback provenance, freeze duration, overhead
measurement and runtime acceptance remain explicit follow-up gates in #159.
