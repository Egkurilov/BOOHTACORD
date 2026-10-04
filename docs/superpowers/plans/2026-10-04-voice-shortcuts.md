# Voice Shortcuts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: execute this plan task-by-task in the current issue worktree.

**Goal:** Add account-scoped microphone and deafen keyboard shortcuts to Web and Windows while preserving the existing voice actions and mobile touch behavior.

**Architecture:** A small pure shortcut model owns validation, formatting, capture semantics and target guards. Web stores bindings per account and routes matching key events to the existing Pinia voice actions. Flutter stores the same binding shape in `AudioPreferences` and handles focused Windows keyboard events in the existing workspace lifecycle; Android/iOS keep the setting hidden.

**Tech Stack:** Vue 3/TypeScript/Vitest, Pinia/localStorage, Flutter/Dart/SharedPreferences, HardwareKeyboard.

---

### Task 1: Web shortcut contract

**Files:**
- Create: `clients/web/src/voice/voice_shortcut.ts`
- Create: `clients/web/src/voice/voice_shortcut_preferences.ts`
- Test: `clients/web/src/voice/voice_shortcut.spec.ts`

- [ ] Write tests for modifier-plus-primary capture, Escape/Tab/Backspace behavior, invalid bare keys, duplicate/search conflicts, blocked targets, formatting, and account-scoped persistence.
- [ ] Implement the pure binding type, validation, formatter, capture helper, event target guard, matching helper, and JSON-safe account preference adapter.
- [ ] Run `npm test -- --run src/voice/voice_shortcut.spec.ts`.

### Task 2: Web runtime and settings wiring

**Files:**
- Create: `clients/web/src/voice/voice_shortcuts.ts`
- Modify: `clients/web/src/voice/activation_store.ts`
- Modify: `clients/web/src/voice/AudioSettings.vue`
- Modify: `clients/web/src/workspace/voice_controls.ts`
- Modify: `clients/web/src/workspace/WorkspaceApp.vue`
- Test: `clients/web/src/voice/voice_shortcuts.spec.ts`

- [ ] Add reactive microphone/deafen bindings, account loading, conflict-safe persistence, and live status text to the activation store.
- [ ] Render two assign/clear rows in audio settings and keep the PTT capture flow intact.
- [ ] Mount one active-tab runtime listener that ignores repeat, IME, editable/dialog targets and delegates to existing `toggleMicrophone`/`toggleDeafen` methods.
- [ ] Add focused runtime tests for action dispatch and ignored contexts.
- [ ] Run focused tests and `npm run build`.

### Task 3: Flutter preference and action contract

**Files:**
- Create: `clients/flutter/lib/src/features/voice/microphone/shortcut.dart`
- Modify: `clients/flutter/lib/src/services/audio_preferences.dart`
- Modify: `clients/flutter/lib/src/features/voice/lifecycle/state.dart`
- Modify: `clients/flutter/lib/src/features/voice/preferences/load.dart`
- Modify: `clients/flutter/lib/src/app/media_access/voice_controls.dart`
- Test: `clients/flutter/test/voice_shortcut_test.dart`

- [ ] Add a serializable binding model and conflict validation tests.
- [ ] Persist both bindings under the existing account-scoped audio preference key with rollback-safe setters.
- [ ] Expose binding state and setters through voice state and preserve existing microphone/deafen constraints.
- [ ] Run `flutter test test/voice_shortcut_test.dart test/audio_preferences_test.dart` when Flutter is available.

### Task 4: Windows workspace capture and UI

**Files:**
- Modify: `clients/flutter/lib/src/screens/workspace_screen.dart`
- Test: `clients/flutter/test/workspace_voice_shortcuts_test.dart`

- [ ] Add focused-app capture for the two actions with Escape cancel, Tab navigation, Backspace/Delete clear, modifier-only rejection, and conflict messages.
- [ ] Match shortcuts before normal PTT handling while retaining interactive-field guards and existing atomic actions.
- [ ] Add desktop-only settings rows and a live semantic status; keep Android/iOS rows hidden.
- [ ] Run focused Flutter tests and `flutter analyze` when available.

### Task 5: Integration and delivery

**Files:**
- Modify: only files listed above.

- [ ] Run Web tests/build and the nearest Flutter tests/analyzer; record unavailable checks explicitly.
- [ ] Inspect changed paths and sizes, commit the issue fix, push the branch, fast-forward `master`, and push `master`.
- [ ] Report issue coverage, test results, and any platform checks unavailable in the environment.
