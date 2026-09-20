# Voice Volume Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide each signed-in browser user an independently persisted 0–200% volume for every remote participant's microphone and selected screen-audio stream without treating a display name or temporary lease as identity.

**Architecture:** LiveKit credentials retain a lease identity but carry a signed `account:<uuid>` metadata value. The browser accepts only that value as a durable remote preference key and stores values under the current account plus the deployment origin in browser storage. An `AudioContext` gain graph applies 0–200%; plain HTML media is only a fallback when Web Audio cannot be created. Remote microphone playback and selected screen audio own their gain handles and accept the same deafen state.

**Tech Stack:** Go 1.25, LiveKit JWT, Vue 3, TypeScript, Pinia, Web Audio API, Vitest.

---

### Task 1: Put a stable remote account key in the scoped LiveKit credential

**Files:**

- Modify: `backend/internal/media/livekit_credential/signer.go`
- Modify: `backend/internal/media/livekit_credential/signer_test.go`
- Modify: `backend/internal/media/issue_livekit_credential/service.go`
- Modify: `backend/internal/media/issue_livekit_credential/service_test.go`

- [x] **Step 1: Write failing signer and issuer tests.**

```go
credential, err := signer.Issue("lease-1", "channel-1", "11111111-1111-4111-8111-111111111111")
claims := decodeClaims(t, credential.Token)
if claims["metadata"] != "account:11111111-1111-4111-8111-111111111111" { t.Fatalf("claims = %#v", claims) }
```

```go
if issuer.accountID != "user-1" { t.Fatalf("account ID = %q", issuer.accountID) }
```

- [x] **Step 2: Run the focused Go tests and confirm the old two-argument issuer fails to compile.**

Run: `go test ./internal/media/livekit_credential ./internal/media/issue_livekit_credential`

Expected: FAIL before the signer and `Issuer` signatures are updated.

- [x] **Step 3: Extend the signing boundary without weakening media grants.**

```go
func (signer Signer) Issue(leaseID, channelID, accountID string) (Credential, error) {
    if leaseID == "" || channelID == "" || accountID == "" { return Credential{}, ErrInvalidConfig }
    token, err := auth.NewAccessToken(signer.config.APIKey, signer.config.APISecret).
        SetIdentity("voice-lease:" + leaseID).
        SetMetadata("account:" + accountID).
        SetVideoGrant(grant).
        SetValidFor(validity).
        ToJWT()
```

Change `Issuer.Issue` to receive `accountID` and call it with `input.ActorID`. Preserve the lease identity, room grant, expiry and no-room-admin behavior.

- [x] **Step 4: Re-run focused Go tests.**

Run: `go test ./internal/media/livekit_credential ./internal/media/issue_livekit_credential`

Expected: PASS.

### Task 2: Apply true 0–200% gain to owned browser audio

**Files:**

- Create: `frontend/src/voice/audio_gain.ts`
- Create: `frontend/src/voice/audio_gain.spec.ts`
- Modify: `frontend/src/voice/remote_voice_playback.ts`
- Modify: `frontend/src/voice/remote_voice_playback.spec.ts`
- Modify: `frontend/src/voice/screen_viewer_controller.ts`
- Modify: `frontend/src/voice/screen_viewer_controller.spec.ts`

- [x] **Step 1: Write failing `AudioMixer` tests with a fake AudioContext.**

```ts
const output = mixer.attach(element)
output.setVolume(200)
expect(gain.gain.value).toBe(2)
output.setMuted(true)
expect(gain.gain.value).toBe(0)
```

Also assert a context-free fallback caps the element volume at `1` while keeping mute semantics.

- [x] **Step 2: Run the focused Vitest file and confirm it fails because `AudioMixer` is absent.**

Run: `npm test -- --run src/voice/audio_gain.spec.ts`

Expected: FAIL with an unresolved module or symbol.

- [x] **Step 3: Implement one reusable mixer with per-element handles.**

```ts
export interface AudioGainHandle { dispose(): void; setMuted(muted: boolean): void; setVolume(percent: number): void }
export class AudioMixer {
  attach(element: HTMLAudioElement): AudioGainHandle { /* createMediaElementSource → GainNode → destination */ }
}
```

Normalize inputs to integer `0…200`. On a valid Web Audio graph set `GainNode.gain.value` to `percent / 100` (or `0` while muted); on graph creation failure use the HTML element's capped `volume` and `muted` properties. `dispose` disconnects both nodes and never removes an element it did not create.

- [x] **Step 4: Wire gain handles into remote microphone and selected screen playback.**

`RemoteVoicePlayback` stores one gain handle per attached remote audio element, exposes `setVolume(participantID, percent)`, and applies stored levels when a track later attaches. `ScreenViewerController` owns one gain handle for its selected screen audio and exposes `setAudioVolume(percent)`. Existing `setDeafened` calls update gain mute state; selecting, unpublishing or clearing disposes the prior handle before detaching its track.

- [x] **Step 5: Run focused audio and viewer tests.**

Run: `npm test -- --run src/voice/audio_gain.spec.ts src/voice/remote_voice_playback.spec.ts src/voice/screen_viewer_controller.spec.ts`

Expected: PASS; `200%` is represented by gain `2`, not a falsified HTML volume value.

### Task 3: Persist levels by signed account identity and surface controls

**Files:**

- Create: `frontend/src/voice/participant_identity.ts`
- Create: `frontend/src/voice/participant_identity.spec.ts`
- Create: `frontend/src/voice/voice_volume_preferences.ts`
- Create: `frontend/src/voice/voice_volume_preferences.spec.ts`
- Modify: `frontend/src/voice/livekit_screen_viewer_adapter.ts`
- Modify: `frontend/src/voice/livekit_screen_viewer_adapter.spec.ts`
- Modify: `frontend/src/voice/livekit_gateway.ts`
- Modify: `frontend/src/voice/voice_session.ts`
- Modify: `frontend/src/voice/connection_store.ts`
- Modify: `frontend/src/voice/ScreenViewer.vue`
- Modify: `frontend/src/conversation/ConversationPane.vue`
- Create: `frontend/src/voice/VoiceParticipantVolumes.vue`
- Modify: `frontend/src/App.vue`

- [x] **Step 1: Write failing pure tests for identity parsing and storage partitioning.**

```ts
expect(accountIdFromMetadata('account:11111111-1111-4111-8111-111111111111')).toBe('11111111-1111-4111-8111-111111111111')
expect(accountIdFromMetadata('account:lease-1')).toBeNull()
preferences.bind('owner-a')
preferences.setParticipant('remote-a', 175)
expect(otherOwner.participant('remote-a')).toBe(100)
```

The storage key must contain the current account ID and remote account ID; deployment partitioning is provided by the browser origin and must be stated in the docs. Do not use a participant display name or temporary lease identity.

- [x] **Step 2: Add preference, adapter and Pinia control code.**

Parse only `account:<UUID>` LiveKit metadata. The adapter uses this stable account ID for remote microphone and screen cards; malformed metadata still plays at default volume but has no persistent preference control. After voice join, load the authenticated current account, bind browser storage, apply saved participant levels to existing/future remote microphone elements and saved stream levels to the selected screen audio. Slider `input` applies gain immediately; `change` writes the normalized value. A storage or session lookup failure leaves audio at `100%` and reports a non-blocking Russian preference error rather than disconnecting voice.

- [x] **Step 3: Add accessible controls.**

`VoiceParticipantVolumes.vue` renders only attached remote microphone cards and labels every range input with the participant's account-derived control ID and current percent. `ScreenViewer.vue` renders a separate selected-stream audio slider only when that stream has audio. Both use `min="0"`, `max="200"`, `step="1"`; every visual level has a textual percentage. Deafen does not erase a saved level.

- [x] **Step 4: Run focused frontend tests and production type-check.**

Run: `npm test -- --run src/voice/participant_identity.spec.ts src/voice/voice_volume_preferences.spec.ts src/voice/livekit_screen_viewer_adapter.spec.ts src/voice/remote_voice_playback.spec.ts src/voice/screen_viewer_controller.spec.ts; npm run build`

Expected: PASS.

### Task 4: Update contracts, traceability and evidence boundaries

**Files:**

- Modify: `TODO.md`
- Modify: `docs/API_AND_REALTIME.md`
- Modify: `docs/superpowers/plans/2026-09-18-voice-volume.md`

- [x] **Step 1: Record the local-persistence boundary.**

State that levels are per deployment origin and authenticated browser account, survive a browser reload, and intentionally do not synchronize to another browser/device. State that signed metadata maps a remote participant to account identity and that neither a display name nor lease ID is a preference key.

- [x] **Step 2: Run full native verification.**

Run: `go test ./...; go vet ./...; go build ./cmd/api; npm test -- --run; npm run build; powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1; powershell -ExecutionPolicy Bypass -File scripts/verify-contracts.ps1; git diff --check`

Expected: PASS. The real browser/LiveKit/Windows/macOS media POC, 0–200 acoustic measurement and release evidence remain open; no mock closes them.

**Coverage review:** This packet addresses the volume portions of REQ-VOICE-01 with true gain semantics and stable per-user keys. It does not claim remote audio playback, metadata visibility, amplification quality or deafen behavior on real hardware; those remain POC/integration evidence.

**Execution note:** Execute inline in the shared dirty worktree. Do not stage, commit, remove or alter unrelated worktree changes.
