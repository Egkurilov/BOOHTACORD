# Flutter Design V2 evidence index

This directory tracks acceptance evidence for backlog task FV2-006: responsive,
accessibility, and Android/macOS/Windows platform acceptance for Flutter Design
V2.

**Status: NOT_RUN.** The implementation and platform acceptance have not been
completed. This index only makes the planned evidence location explicit; it is
not a pass result and does not close FV2-006 or any release gate.

The implementation plan is in
[`docs/superpowers/plans/2026-10-03-design-v2-flutter.md`](../../../docs/superpowers/plans/2026-10-03-design-v2-flutter.md).
Add dated evidence records here as each acceptance run is performed, including
the source revision, platform/device, scenario, commands, result, and limits.

The administrator parity implementation is tracked in
[`qa-admin-parity-2026-10-07-001.json`](../qa-admin-parity-2026-10-07-001.json).
It records the focused Flutter evidence and explicitly leaves unavailable
platform runtime acceptance as `NOT_RUN`; it does not close FV2-006.

## Administration parity follow-up — 2026-10-07

The dedicated branch `codex/issue-188-flutter-admin-completion` now records
responsive Members rows and a Roles before/current/proposed conflict review.
The full Flutter suite passed 791 tests (one expected skip), the changed admin
files analyze cleanly, the dependency guard passed, and version `1.0.38+71`
split APKs were built. Details are in
[`qa-admin-members-responsive-2026-10-07-001.json`](../qa-admin-members-responsive-2026-10-07-001.json)
and
[`qa-admin-roles-conflict-2026-10-07-001.json`](../qa-admin-roles-conflict-2026-10-07-001.json).
These are implementation results; native Android/macOS/iOS/Windows runtime
acceptance remains open under #198. ADB was unavailable during this run.

## macOS admin runtime — 2026-10-07

The native macOS client rendered the complete administrator section set at
`2048x1340`: Guild, Members, Roles, Channels, Audit, Media and Readiness. The
accessibility tree exposed the expected filters, forms, permission controls,
member actions, freshness state and readiness status. This is recorded in
[`qa-admin-macos-runtime-2026-10-07-001.json`](../qa-admin-macos-runtime-2026-10-07-001.json).
It is a macOS admin-surface pass only; live resize and the Android/iOS/Windows
runtime matrix remain open under #198.

## Android admin runtime — 2026-10-07

The arm64 release APK `1.0.38` was installed on the Android 15/API 35
`sdk_gphone64_arm64` emulator. At the portrait `1080x2400` viewport, Members,
Roles, Channels, Audit, Media and Readiness/Status were opened from the admin
tabs; a system Back smoke closed a transient dropdown without leaving the admin
screen. The same admin surface was then checked at `2400x1080` landscape: all
seven tabs remained visible without clipping and each opened successfully before
returning to portrait. The post-run logcat had no fatal app crash. Details are in
[`qa-admin-android-runtime-2026-10-07-001.json`](../qa-admin-android-runtime-2026-10-07-001.json).
IME, TalkBack, iOS and Windows acceptance remain open under #198.

## Accessibility and large-text hardening — 2026-10-07

The admin geometry regression now covers phone portrait/landscape, tablet and
desktop viewports from `360x844` through `1920x1080`, including the compact
thresholds at `844x390` and `1024x768`. A text-scale `2.0` traversal opens every
admin section without a Flutter exception. The run also fixed real large-text
overflows: Channels dropdown labels now expand, while Audit, Media and Readiness
use a scrollable large-text path instead of clipping their primary content.
The full Flutter suite passed 795 tests with one expected skip and the release
APK split build passed. Details are in
[`qa-admin-accessibility-hardening-2026-10-07-001.json`](../qa-admin-accessibility-hardening-2026-10-07-001.json).
This is implementation/widget evidence; native IME, TalkBack, iOS, Windows,
focus-loop and live-resize acceptance remain open under #197/#198.

The current branch was also installed on the Android 15/API 35 emulator after
the hardening commit. The admin screen was opened through the account menu in
portrait and then landscape; all seven tabs remained visible and logcat had no
app fatal exception. This short current-source smoke is recorded in
[`qa-admin-android-runtime-2026-10-07-002.json`](../qa-admin-android-runtime-2026-10-07-002.json).

The follow-up compact identity regression and current-source launch smoke are
recorded in
[`qa-admin-accessibility-hardening-2026-10-07-002.json`](../qa-admin-accessibility-hardening-2026-10-07-002.json).
It raises the full Flutter suite result to 796 passing tests with one expected
skip; the native IME, TalkBack, iOS and Windows gate remains open.
