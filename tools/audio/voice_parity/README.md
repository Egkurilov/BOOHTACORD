# Voice parity physical protocol (#110)

This is a manual hardware/listener gate. No automated acoustic PASS is produced.
Do not record users or add PCM/recordings to the repository.

## Preparation

Use the same USB microphone/headset, input port, placement, gain and OS settings
for Web and Windows. Record driver processing state privately. Disable driver
enhancements for the primary comparison, then separately compare the enabled
driver state. Use a consented operator reading the identical text, or a licensed/
locally authored speech fixture played through the identical physical setup.
Keep fixture audio outside Git. Synthetic tones only check DSP plumbing.

Generate private randomized assignments outside every Git checkout:

```powershell
python tools/audio/voice_parity/blind_trials.py C:\\Temp\\voice-parity-primary
python tools/audio/voice_parity/blind_trials.py C:\\Temp\\voice-parity-dsp --dsp-isolation
python tools/audio/voice_parity/blind_trials.py C:\\Temp\\voice-parity-mobile --mobile
```

Only the operator sees operator-private.json. The listener receives listener.csv
and opaque trial IDs, and must not see the sender/profile/DSP diagnostics.
Primary matrix: four Web/Windows directions × 64/96/128 × clean/keyboard/fan/
double-talk × clean/1%/3% loss = 144 trials. Repeat enough trials with multiple
listeners to assess whether platform identification is reliable; report counts
and uncertainty, not just an overall preference.

## Each trial

1. Leave the room, choose the assigned candidate in audio settings, set the
   assigned AGC/AEC/NS, join. Keep manual gain and VAD threshold fixed; verify PTT
   separately, including mute/deafen/hotkeys. Standard engine first; RNNoise is a
   separate ADR-014 opt-in run. Device switch must preserve the pinned profile.
2. Wait for actual codec/counters, not merely configured values. Export the safe
   report from both real clients. Sample every two seconds for at least 30 seconds
   speech, then 30 seconds silence; counters need two valid measurements. Record
   unavailable values as unavailable. Include processing-hook format and original
   capture confirmation separately.
3. Play/read identical clean speech; repeat keyboard, fan and double-talk. Score
   intelligibility, pumping, clipping, metallic sound, quiet/muffled sound and
   guessed sender platform before revealing assignments.
4. On an isolated test network (never production), apply 1% then 3% packet loss
   on the media path only. Capture actual inbound loss/jitter/concealment; document
   the impairment method and direction. Signaling/auth must remain available.
5. Compare actual speech and silence mean bitrates over equal windows. Account for
   Opus/RED/network overhead; distinguish payload rate from link bandwidth. Check
   DTX with silence measurements, not an options boolean. Explain any cap excess.
6. Force reconnect and replace/unplug the microphone. First rate after replacement
   must be unknown; no stale counters, reconnect leaks or sending while muted.
   Permission-denied listener mode and screen audio must remain independent.

Run DSP isolation assignments to locate gain pumping, AEC metallic/double-talk
artifacts and NS muffling. Change one factor at a time when explaining causality.
Repeat physical Android and iOS sender/receiver paths before cross-platform PASS.
Document fallback/unsupported behavior honestly; do not enable RNNoise globally.

## Evidence and promotion

Attach source revision, client/SDK versions, anonymous paired reports, listener
score counts, network setup and fixture provenance/hash. Never attach raw SDK
stats, track/participant IDs, device labels, precise audio levels or user speech.
Run the new focused unit suites plus existing microphone/device/PTT/reconnect
suites in the owner-requested grouped run. Native validators and builds follow.

Acceptance requires intelligible speech without persistent clipping/pumping/
metallic artifacts and no stable platform distinction in blinded ratings.
64/96 are candidates until measurements demonstrate the desired quality/resource
tradeoff. Update ADR-016 with evidence before changing the default.
