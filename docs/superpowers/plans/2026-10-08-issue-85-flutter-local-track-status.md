# Flutter Local Screen Track Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the source-proven local Flutter screen-share tracks after publication and preserve the existing voice viewer presentation.

**Architecture:** Extract the existing stage label from its 160-line aggregate, leaving the stage entry below the 120-line ratchet. Add a small accessible status leaf rendered only for a local stage; the existing required `VideoTrack` proves video is present and `NativeScreenShareDriver` publishes only video. No capture, publication, admission, or teardown code changes.

**Tech Stack:** Flutter, Dart, flutter_test.

---

### Task 1: Test local and remote stage status

**Files:**
- Test: `clients/flutter/test/screen_share_capability_status_test.dart`
- Create: `clients/flutter/lib/src/features/screen/capabilities/local_track_status.dart`
- Create: `clients/flutter/lib/src/features/screen/stage/label.dart`
- Modify: `clients/flutter/lib/src/screens/voice_screen_stage.dart`

- [ ] Add tests that expect video-present/audio-not-sent and voice-continuity copy only for a local stage.
- [ ] Run `flutter test test/screen_share_capability_status_test.dart` from `clients/flutter/` and confirm the missing leaf makes it fail.
- [ ] Move the existing stage label verbatim to its child file; preserve keys, sizing, labels and styling.
- [ ] Add the accessible local track status leaf and render it only in `VoiceScreenStage` when `isLocal` is true.
- [ ] Run the focused test, `flutter analyze`, `flutter test test/voice_screen_stage_test.dart test/screen_share_lifecycle_contract_test.dart`, and `git diff --check`.

**Scope boundary:** Pre-picker platform matrix remains separate because the 778-line source-picker/quality dialog has no extracted leaves yet. This slice makes no device-level capability claim; physical acceptance remains separate.
