# Windows voice overlay speaker filter Implementation Plan

> **For agentic workers:** Use the inline implementation in this task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an account-scoped Windows overlay preference that can filter the overlay roster to active speakers.

**Architecture:** Keep preference storage and the control inside the existing `features/voice/overlay` leaf. Load the preference with the active account lifecycle, clear in-memory state at sign-out, and pass the filter value into the existing snapshot projection. The control remains in the Windows-only voice dock and the existing native window and LiveKit session remain unchanged.

**Tech Stack:** Flutter/Dart, SharedPreferences, Flutter widget and unit tests.

---

### Task 1: Persist account-scoped speaker filter

**Files:**
- Create `clients/flutter/lib/src/features/voice/overlay/preferences.dart` for account-keyed local persistence.
- Create `clients/flutter/test/voice_overlay/preferences_test.dart` for load, write, and account isolation.
- Modify `clients/flutter/lib/src/app/composition/owners.dart`, `clients/flutter/lib/src/app/account_lifecycle/initialize.dart`, and `clients/flutter/lib/src/app/account_lifecycle/clear.dart` to own/load/reset active overlay preference state.

- [ ] Write tests for default false, saved value round-trip, and distinct account keys.
- [ ] Run the focused preferences test and confirm the new API is missing.
- [ ] Implement the preference value with `SharedPreferences` key `voice-overlay:v1:<accountId>:only-speakers`; load failure falls back to false.
- [ ] Load only after the current account is validated, then run preference tests.

### Task 2: Feed preference into existing projection

**Files:**
- Modify `clients/flutter/lib/src/features/voice/overlay/feed.dart` and `current_feed.dart`.
- Modify `clients/flutter/test/voice_overlay/feed_test.dart`.

- [ ] Add a test proving changing `onlySpeakers` recomputes the visible snapshot while enabled.
- [ ] Change the feed projection callback to accept `enabled` and `onlySpeakers`.
- [ ] Add an idempotent feed setter and reset the in-memory filter to false at account cleanup.
- [ ] Run focused feed and projection tests.

### Task 3: Expose the filter in the Windows voice dock

**Files:**
- Modify `clients/flutter/lib/src/features/voice/overlay/toggle.dart` and `clients/flutter/lib/src/screens/workspace_screen.dart`.
- Modify `clients/flutter/test/voice_overlay/toggle_test.dart`.

- [ ] Add a Windows-only accessible menu item for “Показывать только говорящих” and verify callback/state behavior in a widget test.
- [ ] Wire menu changes through `AppOwners` to feed and persisted preference; on storage failure, restore the last active value.
- [ ] Run focused overlay tests and static analysis, then document the slice and remaining #112 source and manual runtime scope.
