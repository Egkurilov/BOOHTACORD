# Actual AdminScreen timeout launch integration

Route: small_direct, actual member actions -> admin_ui/voice_timeout -> existing scoped timeout dialog/API. Existing admin role/save/reset/kick callbacks and draft handling preserved; no Voice Join or microphone/media ownership changes.

Before: compact/desktop launch tests failed because the action was missing. After wiring: GET targets the selected account at390/1440; AppState scope notifier reaches the dialog and nested confirmation. Original session-boundary privacy tests remain green.

Actual initial Escape tests then failed because focus stayed outside the shortcut subtree until a control was focused. Shared route now owns an autofocus FocusScope, closed-loop traversal and reduced motion. Escape uses maybePop, preserving the timeout's busy PopScope; the pending-GET test proves busy dismissal is blocked and completed dismissal succeeds.

Popup selection was physically split before adding timeout. Stable popup state plus Enter/Space bindings make restored anchor focus actionable; the desktop test reopens the actual menu with Enter after timeout Escape. Pointer cancellation/system Back and role/deletes dialog tests remain green.

The old compact test measured geometry after an ineffective Escape. It now checks the same safe bounds before Escape and explicitly verifies dismissal afterwards; geometry/privacy/mutation checks were retained.

Contracts caught role feature -> application widgets imports. Shared confirmation moved physically to features/admin/confirmation/dialog.dart; the old widget path remains an export facade. Role leaves import the feature helper directly, preserving public signatures.

- Actual timeout/accessibility combined:71 PASS (33 timeout +38 admin); zero skips.
- Nine actual timeout+confirmation routes:390/600/1440 x1.0/1.3/2.0 with300px IME, PASS.
- Scoped analysis: no issues before helper relocation; final native suite/analyzer verifies the integrated source.
- Canonical native contracts: PASS after physical helper movement; local Dart boundaries1395 PASS.
- New/touched root production Dart files are within100 lines.

Synthetic API fixtures exercise actual widgets/routes/AppState. Server ACL and SFU revocation are separate Go/PostgreSQL tests and deployed QA. Physical IME/screen readers, released native builds and production revocation remain #287/#197/#97 acceptance, not implied by these widget checks.

## Windows engine regression and narrow fix

Owned hidden Windows engine at source559abdbf measured40dp grant/confirmation targets under the real guildTheme desktop compact density. This is a source defect, not a physical acceptance PASS. Nine Windows-platform tests reproduce red40dp targets across390/600/1440 widths and text scale1/1.3/2 with300px simulated IME.

Timeout action/confirmation buttons now use an explicit minimum44dp and standard density in their own leaf; global theme and other media/UI ownership are unchanged. All six action types (grant, lift, refresh, close, cancel, confirm) are measured. Focused timeout/admin suite:80 PASS, zero skips. Final engine rerun and canonical native validation are recorded separately with their exact source SHA. Physical input, screen readers and device release remain NOT_RUN until separately evidenced.

The actual AdminScreen launch test also uses Windows platform/compact density: compact390px trigger reproduced40dp, while the1440px popup remained44dp. Standard density is now explicit on the compact timeout trigger. Both launch geometry/keyboard routes and all80 focused checks pass after this additional fix.
