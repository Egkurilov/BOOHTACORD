# Voice shortcut completion plan

> Execute inline with the repository method. Owner deferred native runs/builds.

**Goal:** Complete #106 physical-key, lifecycle, conflict, reset and status behavior.
**Architecture:** Preserve existing microphone/deafen controllers and touch PTT.
Extract shortcut ownership into Web and native voice/shortcuts leaves; retain
legacy imports as forwarding wrappers. Native old logical bindings remain readable,
while new capture stores physical USB code. No key/input telemetry is added.
**Tech stack:** Vue/Pinia/TypeScript and Flutter HardwareKeyboard/SharedPreferences.

## Route and preservation

T-022 depends on T-006/T-020. UX bindings follow T-050/T-051.
Baseline 6aa94ee4 is already in master. Keep existing audio state/ACL/media cleanup,
secure session scope and existing mute/output-disable/restore operations.
Source target100/hard120; only thin bindings touch legacy large store/workspace.

## Authored tests before changes

- [x] Web shortcuts/model.spec.ts: physical code vs translated key, modifier-only,
  search/browser/OS conflicts, native dialog, repeat/IME/Tab/cancel/clear.
- [x] Web shortcuts/runtime.spec.ts: active focus, once while command pending,
  stop invalidation, editable/modal exclusion and listener/reconnect/PTT guards.
- [x] Web shortcuts/preferences.spec.ts: account isolation, explicit reset,
  malformed/duplicate/reserved restored bindings and failed persistence.
- [x] Native voice_shortcut_lifecycle_test.dart and widget test: physical capture,
  migrated legacy binding, blocked states, cancel/clear/Tab, account cleanup,
  reset, focus/dialog/mobile capability and visible live status.

## Web leaf and exact bindings

- [x] Physically move voice_shortcut/voice_shortcuts runtime into shortcuts child
  leaf; wrappers export the existing public contract.
- [x] Add execution helper that guards phase/capture/listener/PTT, calls existing
  toggle methods, and determines applied/blocked from resulting authoritative state.
- [x] Runtime serializes commands and discards completion after stop/new context.
- [x] Extract account settings into shortcuts/state.ts; validate restored conflicts,
  expose reset and clear transient state on unbind.
- [x] Bind Workspace voice_controls to guarded commands; set listenerOnly on
  admitted Web session (optional typed metadata; no business-state duplication).
- [x] ShortcutSettings supplies blur cancellation and explicit reset. Workspace
  renders a visible, accessible status component outside settings.

## Native leaf and exact bindings

- [x] Move microphone/shortcut.dart model to shortcuts/model.dart forwarding
  old imports; add physicalKeyId to new captures and serialized preferences.
- [x] Split assignment/reset from preferences/load.dart into preferences/shortcuts.dart.
- [x] Add shortcuts execution owner using session/room ownership and busy token;
  cancel on account teardown/dispose/focus loss. Existing toggles remain authoritative.
- [x] Extract native capture/focus and settings row widgets from workspace_screen.
  Track foreground; mobile setting appears only after hardware-key detection.
- [x] Add one visible live status region in workspace; preserve touch PTT.

## Delivery and deferred checks

- [x] Record NOT_RUN evidence and focused commands; document active-app scope,
  reserved combinations, mobile keyboard discovery and legacy-binding migration.
- [ ] Inspect exact sizes/status, commit selected files, push/attach PR and merge
  to master with [skip ci].
- [ ] Deferred: Web focused vitest + vue-tsc, Windows Flutter focused widget tests
  + analysis, Web e2e and real Windows focus/keyboard/layout checks, Android/iOS
  hardware/touch regression. No new build or deployment now.

Stop: code merged; #106 stays open until grouped physical/automated acceptance.
