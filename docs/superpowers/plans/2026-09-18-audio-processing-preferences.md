# Account-Scoped Audio Processing Preferences Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist AGC, echo-cancellation, and noise-suppression preferences per signed-in account and deployment origin before microphone capture begins.

**Architecture:** A storage leaf accepts only the three boolean browser-processing settings and namespaces its local-storage key with the current account ID; browser origin naturally scopes it to a deployment. A controller loads that state before `VoiceSession.join`, requests the constraints through the existing session interface, and writes only after an active track accepts the change.

**Tech Stack:** Vue 3, Pinia, TypeScript, Vitest, browser localStorage, LiveKit JS client.

---

### Task 1: Account-scoped preference storage

**Status:** Complete — storage isolation and malformed-data fallback tests pass.

**Files:**
- Create: `frontend/src/voice/audio_processing_preferences.ts`
- Create: `frontend/src/voice/audio_processing_preferences.spec.ts`

- [x] **Step 1: Write the failing storage tests**

```ts
const storage = memoryStorage()
const owner = new AudioProcessingPreferences(storage)
const other = new AudioProcessingPreferences(storage)
owner.bind('owner-a')
other.bind('owner-b')
owner.set({ autoGainControl: false, echoCancellation: false, noiseSuppression: true })
expect(owner.get()).toEqual({ autoGainControl: false, echoCancellation: false, noiseSuppression: true })
expect(other.get()).toEqual(defaultAudioProcessing)
```

- [x] **Step 2: Run the storage test to verify it fails**

Run: `npm test -- --run src/voice/audio_processing_preferences.spec.ts`

Expected: FAIL because `AudioProcessingPreferences` does not exist.

- [x] **Step 3: Implement validated, account-namespaced storage**

```ts
function isAudioProcessingOptions(value: unknown): value is AudioProcessingOptions {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false
  const candidate = value as Partial<AudioProcessingOptions>
  return typeof candidate.autoGainControl === 'boolean' && typeof candidate.echoCancellation === 'boolean' && typeof candidate.noiseSuppression === 'boolean'
}
export class AudioProcessingPreferences {
  private accountId: string | null = null
  bind(accountId: string): void { this.accountId = accountId }
  clear(): void { this.accountId = null }
  get(): AudioProcessingOptions {
    const key = this.key()
    if (!key || !this.storage) return { ...defaultAudioProcessing }
    try {
      const source: unknown = JSON.parse(this.storage.getItem(key) ?? '{}')
      if (!isAudioProcessingOptions(source)) return { ...defaultAudioProcessing }
      return { ...source }
    } catch { return { ...defaultAudioProcessing } }
  }
  set(next: AudioProcessingOptions): void {
    const key = this.key()
    if (!key || !this.storage) return
    try { this.storage.setItem(key, JSON.stringify(next)) } catch {}
  }
  private key(): string | null { return this.accountId ? `audio-processing:v1:${this.accountId}` : null }
}
```

- [x] **Step 4: Run the storage test to verify it passes**

Run: `npm test -- --run src/voice/audio_processing_preferences.spec.ts`

Expected: PASS with account isolation and malformed-data defaults covered.

### Task 2: Load and save preferences through a dedicated controller

**Status:** Complete — controller and store tests pass.

**Files:**
- Create: `frontend/src/voice/audio_processing_controls.ts`
- Create: `frontend/src/voice/audio_processing_controls.spec.ts`
- Modify: `frontend/src/voice/audio_settings_store.ts`
- Modify: `frontend/src/voice/audio_settings_store.spec.ts`

- [x] **Step 1: Write failing controller tests**

```ts
const controls = createAudioProcessingControls(async () => ({ accountId: 'owner-a' }), preferences)
await controls.start(apply)
expect(apply).toHaveBeenCalledWith(saved)
await controls.set(next, apply)
expect(preferences.get()).toEqual(next)
```

- [x] **Step 2: Run controller and store tests to verify failure**

Run: `npm test -- --run src/voice/audio_processing_controls.spec.ts src/voice/audio_settings_store.spec.ts`

Expected: FAIL because the controller and store initialization boundary do not exist.

- [x] **Step 3: Implement load-before-join and write-after-apply behavior**

```ts
async function start(apply: AudioProcessingApplier): Promise<void> {
  preferences.clear()
  processing.value = { ...defaultAudioProcessing }
  error.value = null
  try {
    preferences.bind((await loadAccount()).accountId)
    processing.value = preferences.get()
  } catch { error.value = 'Не удалось загрузить настройки обработки микрофона; используются значения по умолчанию.' }
  await apply(processing.value)
}
async function set(next: AudioProcessingOptions, apply: AudioProcessingApplier): Promise<void> {
  await apply(next)
  preferences.set(next)
  processing.value = { ...next }
}
```

- [x] **Step 4: Run controller and store tests to verify pass**

Run: `npm test -- --run src/voice/audio_processing_controls.spec.ts src/voice/audio_settings_store.spec.ts`

Expected: PASS with a non-persistent default fallback on account lookup failure.

### Task 3: Initialize settings before voice admission and document scope

**Status:** Complete — workspace ordering test and TODO update are in place.

**Files:**
- Modify: `frontend/src/workspace/voice_controls.ts`
- Modify: `frontend/src/workspace/voice_controls.spec.ts`
- Modify: `TODO.md`

- [x] **Step 1: Write a failing workspace control test**

```ts
await controls.joinVoice('voice-1')
expect(loadProcessing).toHaveBeenCalledBefore(voiceConnection.join)
```

- [x] **Step 2: Run the workspace test to verify failure**

Run: `npm test -- --run src/workspace/voice_controls.spec.ts`

Expected: FAIL because `joinVoice` does not initialize processing settings.

- [x] **Step 3: Call the store initializer immediately before `voiceConnection.join`**

```ts
await audioSettings.loadProcessing(voiceConnection.setAudioProcessing)
await voiceConnection.join(channelId, transfer)
```

- [x] **Step 4: State the persistence boundary in TODO**

```md
Preferences persist only in browser storage for the same deployment origin and signed-in account; they are not synchronized across devices.
```

- [x] **Step 5: Run the native checks**

Run: `npm test -- --run`, `npm run build`, `scripts/verify-spec-traceability.ps1`, and `git diff --check`.

Expected: all tests and build pass; traceability reports all requirements.

## Self-review

Coverage: Task 1 covers account/origin storage isolation, Task 2 loads and writes only validated settings, and Task 3 ensures saved values precede microphone capture and documents cross-device scope. No hardware or browser-effect claim is introduced.

Type consistency: `AudioProcessingOptions` remains the single settings type; both the controller and `VoiceSession.setAudioProcessing` use it unchanged.
