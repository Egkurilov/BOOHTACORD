# Screen Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the selected screen-share target separately from measurements that the browser and LiveKit SDK actually report, without inventing media capability or POC success.

**Architecture:** Keep browser/LiveKit type knowledge at the `livekit_gateway` boundary. A small diagnostics value object normalizes optional capture settings and sender statistics; `VoiceSession` exposes it to the existing screen-controls store, and the voice view renders unknown values honestly. Capture failures remain classified at the UI boundary and do not change voice admission or WebRTC reconnect semantics.

**Tech Stack:** Vue 3, TypeScript, Pinia, Vitest, LiveKit Client 2.22.3.

---

### Task 1: Normalize safe diagnostic values

**Files:**

- Create: `frontend/src/voice/screen_diagnostics.ts`
- Test: `frontend/src/voice/screen_diagnostics.spec.ts`

- [ ] **Step 1: Write failing unit tests for partial and complete stats.**

```ts
expect(normalizeScreenDiagnostics({ audioTrack: true, settings: { width: 1920, height: 1080, frameRate: 60 }, sender: { frameWidth: 1280, frameHeight: 720, framesPerSecond: 30, packetsLost: 2, roundTripTime: 0.04, qualityLimitationReason: 'bandwidth' } })).toEqual({ audioTrack: 'PRESENT', measured: { width: 1280, height: 720, framesPerSecond: 30 }, packetsLost: 2, roundTripTimeMs: 40, adaptationReason: 'bandwidth', source: 'ACTIVE' })
expect(normalizeScreenDiagnostics({ audioTrack: false, settings: {}, sender: undefined })).toMatchObject({ audioTrack: 'ABSENT', measured: null, source: 'UNKNOWN' })
```

- [ ] **Step 2: Run the focused test and verify it fails before the implementation exists.**

Run: `npm test -- --run src/voice/screen_diagnostics.spec.ts`

Expected: FAIL because `screen_diagnostics.ts` does not exist.

- [ ] **Step 3: Add the minimal normalizer.**

```ts
export type ScreenAudioTrackStatus = 'PRESENT' | 'ABSENT' | 'UNKNOWN'
export interface ScreenDiagnostics { audioTrack: ScreenAudioTrackStatus; measured: { width: number; height: number; framesPerSecond?: number } | null; packetsLost?: number; roundTripTimeMs?: number; adaptationReason?: string; source: 'ACTIVE' | 'ENDED' | 'UNKNOWN' }

export function normalizeScreenDiagnostics(input: RawScreenDiagnostics): ScreenDiagnostics {
  // Prefer sender dimensions/FPS, fall back to browser capture settings, and omit unavailable values.
}
```

- [ ] **Step 4: Run the focused test and verify it passes.**

Run: `npm test -- --run src/voice/screen_diagnostics.spec.ts`

Expected: PASS with complete and unavailable values distinct.

### Task 2: Bind real LiveKit capture and sender statistics

**Files:**

- Modify: `frontend/src/voice/livekit_gateway.ts`
- Modify: `frontend/src/voice/livekit_gateway.spec.ts`

- [ ] **Step 1: Write failing gateway assertions for measured data.**

```ts
const diagnostics = await startScreenShare(fakeRoom, 'P1080_60')
expect(diagnostics.audioTrack).toBe('ABSENT')
expect(diagnostics.measured).toEqual({ width: 1280, height: 720, framesPerSecond: 30 })
```

- [ ] **Step 2: Run the focused test and verify it fails.**

Run: `npm test -- --run src/voice/livekit_gateway.spec.ts`

Expected: FAIL because `startScreenShare` currently resolves `void`.

- [ ] **Step 3: Return an adapter instead of exposing the raw dynamic SDK room.**

```ts
const { Room, Track } = await import('livekit-client')
const room = new Room({ reconnectPolicy: new BoundedVoiceReconnectPolicy() })
return {
  connect: (url, token) => room.connect(url, token),
  disconnect: () => room.disconnect(),
  on: (event, listener) => { room.on(event, listener); return adapter },
  readScreenDiagnostics: async () => normalizeScreenDiagnostics({
    audioTrack: Boolean(room.localParticipant.getTrackPublication(Track.Source.ScreenShareAudio)?.audioTrack),
    videoTrack: room.localParticipant.getTrackPublication(Track.Source.ScreenShare)?.videoTrack,
  }),
  localParticipant: { /* delegate microphone and screen methods */ },
}
```

The adapter must use the local screen video track's `getSourceTrackSettings()` and `getSenderStats()` APIs, never a fixed profile value. Missing tracks/stats stay `UNKNOWN`; no profile is marked supported.

- [ ] **Step 4: Run the focused test and verify it passes.**

Run: `npm test -- --run src/voice/livekit_gateway.spec.ts`

Expected: PASS; the profile is sent to the system picker and the returned diagnostics remain measured/optional.

### Task 3: Surface state and precise user recovery messages

**Files:**

- Modify: `frontend/src/voice/voice_session.ts`
- Modify: `frontend/src/voice/screen_controls.ts`
- Create: `frontend/src/voice/screen_controls.spec.ts`
- Modify: `frontend/src/voice/connection_store.ts`

- [ ] **Step 1: Write failing screen-control tests for no-audio, source-ended and distinct capture errors.**

```ts
await controls.startScreen('P1080_60')
expect(screenDiagnostics.value.audioTrack).toBe('ABSENT')
expect(screenError.value).toContain('без аудиодорожки')
await expect(controls.startScreen('P1080_60')).resolves.toBeUndefined()
```

- [ ] **Step 2: Run the focused test and verify it fails.**

Run: `npm test -- --run src/voice/screen_controls.spec.ts`

Expected: FAIL because controls do not hold diagnostics or classify these outcomes.

- [ ] **Step 3: Thread the diagnostic value through the existing session and Pinia store.**

```ts
async startScreen(profile: ScreenProfile): Promise<ScreenDiagnostics> {
  if (!this.current) throw new Error('Сначала подключитесь к голосовому каналу.')
  const diagnostics = await startScreenShare(this.current.room, profile)
  this.current.screenProfile = profile
  return diagnostics
}
```

Classify `AbortError` as picker cancellation, `NotAllowedError` as denied access, no audio track as a non-fatal actionable warning, an ended source as a restart instruction, and `bandwidth` sender limitation as congestion. Keep unrecognised browser errors explicit and do not claim why they happened.

- [ ] **Step 4: Run the focused test and verify it passes.**

Run: `npm test -- --run src/voice/screen_controls.spec.ts`

Expected: PASS; existing voice state stays active while an absent screen-audio track is visible.

### Task 4: Render target versus measurement

**Files:**

- Modify: `frontend/src/conversation/ConversationPane.vue`
- Modify: `frontend/src/App.vue`
- Modify: `TODO.md`
- Modify: `docs/API_AND_REALTIME.md`

- [ ] **Step 1: Add the screen diagnostics props and template.**

```vue
<p v-if="screenState === 'SHARING'">Цель: {{ screenProfile }}. Измерено: {{ measuredMode }}.</p>
<p>Аудиодорожка: {{ audioTrackLabel }}. Качество: {{ connectionQualityLabel }}.</p>
<details><summary>Технические данные</summary><p>{{ technicalMetrics }}</p></details>
```

The view must show `нет данных` rather than deriving dimensions, FPS, bitrate, RTT or loss from the chosen profile.

- [ ] **Step 2: Update docs and the unchecked TODO entry.**

Document that these are browser/SDK observations, not POC evidence or a quality/capacity guarantee. Record the implementation as partial until Windows/macOS evidence is available.

- [ ] **Step 3: Run all frontend checks.**

Run: `npm test -- --run; npm run build`

Expected: PASS; a size warning alone is not a failed check.

### Task 5: Verify cross-project invariants

**Files:**

- Modify: `docs/MEDIA_PROTOTYPE.md` only if an observable/manual step changes.

- [ ] **Step 1: Run traceability and inspect the product diff.**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-spec-traceability.ps1; git diff --check`

Expected: traceability passes; no whitespace error.

- [ ] **Step 2: Inspect status and changed file sizes without staging.**

Run: `git status --short; Get-ChildItem frontend/src/voice/{screen_diagnostics.ts,screen_controls.ts,livekit_gateway.ts} | Select-Object Name,Length`

Expected: only the selected leaf and its supporting view/docs changed; no generated artifact or evidence is treated as a completed POC.

**Coverage review:** The plan covers REQ-SCREEN-01's target-versus-measured distinction and REQ-SCREEN-04's audio/technical data plus separate recovery states. It deliberately does not claim REQ-SCREEN-03 viewing/subscription or POC-01/02 hardware evidence, which require separate leaves and real machines.

**Execution note:** The shared worktree is already dirty and has no configured Git identity; inspect status but do not stage or commit this packet.
