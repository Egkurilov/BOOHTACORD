# Registration Password Generator Implementation Plan

> **For agentic workers:** execute this plan task-by-task in the current issue worktree.

**Goal:** Offer an optional 24-character cryptographically generated registration password on Web and Flutter without exposing or persisting the secret.

**Architecture:** A pure generator uses rejection sampling and an injectable byte source, with platform adapters using Web Crypto or `Random.secure()`. Authentication screens own only transient password text, explicit replacement confirmation, visibility, focus and non-secret live status.

**Tech Stack:** Vue 3/TypeScript/Vitest/Web Crypto, Flutter/Dart/Random.secure/flutter_test.

---

### Task 1: Secure generator contracts

**Files:**
- Create: `clients/web/src/identity/password_generator.ts`
- Test: `clients/web/src/identity/password_generator.spec.ts`
- Create: `clients/flutter/lib/src/services/password_generator.dart`
- Test: `clients/flutter/test/password_generator_test.dart`

- [ ] Test exact length, ASCII alphabet, mandatory upper/lower/digit/symbol classes, deterministic injectable bytes, and rejection at byte boundaries.
- [ ] Implement rejection-sampling index selection, mandatory class selection, cryptographic Fisher–Yates shuffle, and platform defaults (`crypto.getRandomValues` / `Random.secure`).
- [ ] Run focused Web tests and the Flutter focused test when the SDK is available.

### Task 2: Web registration UX

**Files:**
- Modify: `clients/web/src/identity/AuthenticationLanding.vue`
- Test: `clients/web/src/identity/password_generator_ui.spec.ts`

- [ ] Add registration-only Generate button, explicit replacement confirmation for non-empty input, show generated password, focus the password field, and announce only `Надёжный пароль сгенерирован` through `aria-live`.
- [ ] Clear transient secret and hide it on mode changes, successful authentication and component unmount; retain manual input and never copy or log the secret.
- [ ] Run focused tests and Web build.

### Task 3: Flutter registration UX

**Files:**
- Modify: `clients/flutter/lib/src/screens/auth_screen.dart`
- Test: `clients/flutter/test/auth_screen_test.dart`

- [ ] Add registration-only generator and explicit replacement confirmation, transient reveal, focus restoration, autofill/new-password settings, live semantic status, and mode/dispose cleanup.
- [ ] Keep login layout and reset/server actions unchanged.
- [ ] Run focused Flutter tests and analyzer when the SDK is available.

### Task 4: Delivery verification

- [ ] Run the full Web test suite and build, inspect changed paths and sizes, commit, fast-forward `master`, push, and verify CI Android/Flutter/Windows jobs.
- [ ] Report unavailable local Flutter checks and CI results without including any generated password in output.
