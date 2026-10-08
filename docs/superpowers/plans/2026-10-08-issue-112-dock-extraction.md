# Windows Voice Overlay Dock Binding Extraction Implementation Plan

> **For agentic workers:** Execute this plan inline in the assigned isolated worktree; preserve existing behavior and run the focused Flutter checks.

**Goal:** Move the Windows overlay's state-to-control wiring behind a small voice-overlay leaf so future settings can evolve without adding behavior to the workspace-screen aggregate.

**Architecture:** Introduce an immutable `VoiceOverlayDockBinding` in the existing `features/voice/overlay` route. `AppOwners` will construct that binding from its existing feed and callbacks; a leaf `VoiceOverlayDock` will translate it to the already-tested `VoiceOverlayToggle`. Replace the workspace screen's inline property mapping with one call. Keep the existing toggle, account-scoped speaker filter, platform check, accessibility labels, and callback behavior unchanged.

**Tech Stack:** Flutter/Dart, Flutter widget tests, existing `AppOwners` composition.

---

## Route and preservation baseline

- Workflow class: `split_first`; task size: medium; structure mode: `structure_no_rg` before route selection, then exact-edge searches only.
- Route: `clients/flutter/lib/src/features/voice/overlay/` with composition edge in `clients/flutter/lib/src/app/composition/owners.dart` and one forwarding call in `clients/flutter/lib/src/screens/workspace_screen.dart`.
- Current behavior to preserve: Windows-only visibility toggle; hidden on other platforms; available only while connected/listener; visibility updates call `setVoiceOverlayEnabled`; only-speakers updates call the asynchronous account-checked `setVoiceOverlayOnlySpeakers`; no new data or side effects.
- Ratchets: each new/changed leaf file <=120 lines; leaf production/test files <=8 each. Do not edit generated artifacts or touch native runner behavior.
- Stop condition: if testable widget boundary or an import-safe composition edge cannot be maintained without restructuring the aggregate, stop before edits.

## Task 1: Add a failing behavior test for the bound dock control

**Files:**
- Create: `clients/flutter/test/voice_overlay/dock_test.dart`
- Create: `clients/flutter/lib/src/features/voice/overlay/dock.dart`
- Test command: `flutter test --no-pub test/voice_overlay/dock_test.dart` from `clients/flutter`

- [ ] Define a small widget test that creates `VoiceOverlayDockBinding(enabled: false, onlySpeakers: false, available: true, ...)`, pumps `VoiceOverlayDock`, taps the existing visibility toggle, opens overlay settings, selects only-speakers, and verifies each owner callback is called with `true`.
- [ ] Run the test before implementation and confirm it fails because `dock.dart` is absent.
- [ ] Add an unavailable-state assertion: the visibility toggle and settings menu remain disabled when `available` is false.
- [ ] Keep direct presentation tests in `toggle_test.dart` unchanged.

## Task 2: Implement the leaf binding and owner factory

**Files:**
- Create: `clients/flutter/lib/src/features/voice/overlay/dock.dart`
- Modify: `clients/flutter/lib/src/app/composition/owners.dart`

- [ ] Add immutable binding fields `enabled`, `onlySpeakers`, `available`, `onVisibilityChanged`, and `Future<void> Function(bool) onOnlySpeakersChanged`.
- [ ] Add `VoiceOverlayDock`, a thin widget that builds `VoiceOverlayToggle` from those fields; bridge the async preference callback with `unawaited` so widget callbacks remain non-blocking as today.
- [ ] Add `AppOwners.voiceOverlayDockBinding({required bool available})` returning current feed flags and the existing two owner methods. Do not alter those methods or account lifecycle.
- [ ] Keep each touched production file <=120 lines and the overlay leaf within 8 production/direct-test files.

## Task 3: Rewire the existing screen edge and run checks

**Files:**
- Modify: `clients/flutter/lib/src/screens/workspace_screen.dart`
- Validate:
  - `flutter test --no-pub test/voice_overlay/dock_test.dart test/voice_overlay/toggle_test.dart`
  - `flutter analyze --no-pub lib/src/features/voice/overlay/dock.dart lib/src/app/composition/owners.dart lib/src/screens/workspace_screen.dart`
  - `git diff --check`

- [ ] Replace the direct `VoiceOverlayToggle` constructor and inline callback/property map with `VoiceOverlayDock(binding: state.voiceOverlayDockBinding(available: _connected))`.
- [ ] Keep all other screen layout, conditions, imports, and voice/session actions unchanged.
- [ ] Re-read the patch and confirm there is no change to ACL, identity scoping, channel selection, filter behavior, LiveKit, microphone, or native transport.

## Task 4: Review and hand off

- [ ] Confirm all changed files' line counts and direct-test counts against the route ratchets.
- [ ] Inspect `git status --short`, stage only the focused source/test/plan files, and push the semantic `codex/issue-112-overlay-next` branch.
- [ ] Open a PR referencing #112 only if focused tests and exact-head CI pass. Do not close #112; placement/scale/transparency controls, hotkey/conflict behavior, edit mode, monitor/DPI restoration, broad accessibility, and physical Windows/game/performance acceptance remain outside this extraction.
