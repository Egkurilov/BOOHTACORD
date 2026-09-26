# Flutter ↔ web parity TODO

Source of truth: [`flutter-web-parity.md`](flutter-web-parity.md). Keep this
execution list synchronized with the parity map and mark an item done only after
its behavior and platform-specific acceptance evidence exist.

## P0 — Complete admin topology workflows

- [x] Reorder categories and channels using the current topology revision;
  reload after success and on `409`, and preserve selection where possible.
- [x] Move a channel between categories without changing its kind; recover from
  stale revisions and show the server's authorization/error copy.
- [x] Archive TEXT channels and close VOICE admission only after explicit,
  web-equivalent confirmation; refresh topology and accurately report server
  results (never imply that a lease count proves SFU disconnection).
- [x] Add API contract tests for every admin topology request.
- [ ] Add widget coverage for disabled/pending controls and stale-conflict
  recovery; confirmation dialogs and cancellation already have widget coverage.

## P1 — Admin members and audit

- [x] Paginate `/admin/accounts` (100 per page); edit role/block state and save
  per-row.
- [x] Widget-test account pagination, preserving drafts on failure, focus after
  save, and per-row error/success announcements.
- [x] Create and copy expiring password-reset links in in-memory UI state; close
  removes the link from the screen.
- [x] Add widget coverage for reset-link expiry/copy/close and creation errors.
- [x] Add the administrator voice-kick action only for another same-voice
  participant and distinguish an absent lease from a revoked lease.
- [x] Paginate `/admin/audit` with the opaque `before` cursor and render the
  web event presentation without message contents.
- [x] Add widget coverage for audit initial/older-page loading, empty, error,
  refresh and older-page rendering states.
- [x] Add the Members / Channels / Audit tab structure and role-gated entry.
- [ ] Verify administrator REST ACL behavior against the running backend.

## P1 — Reliable conversations and attachments

- [ ] Add per-file upload progress/retry and safe cleanup/recovery for abandoned
  uploads in TEXT and DM; preserve successful attachment IDs on partial failure.
- [x] Add optimistic sending/failed rows and explicit retry controls in TEXT
  and DM. Exact-payload retries reuse `client_message_id`, reconcile server
  acknowledgements from history, and cannot populate another open chat.
- [ ] Add edit/delete revision-conflict recovery and verify send retry against
  the live backend.
- [ ] Verify reply context, pagination/scroll restoration and read cursors at
  boundaries and under realtime updates.
- [ ] Define a native notification design per platform before exposing any
  notification preference; account for permission denial and deduplication.

## P1 — Voice and screen-share behavior

- [ ] Verify that a locally published screen can be reopened from the "Вы"
  participant card after returning to the roster on macOS and Android; the
  reopen control and its compact card layout have widget coverage.
- [ ] Verify enumeration and switching of named microphones and outputs,
  including device hotplug, on macOS, Windows and Android. The dropdown now
  renders named devices when the native SDK has no `default` entry, and the
  audio panel follows device-change events without reverting to stale scans.
- [ ] Match permission-denied/prejoin/dock copy and accessible states.
- [ ] Specify and test bounded reconnect behavior against LiveKit's retry
  ownership; avoid competing retry loops or duplicate voice leases.
- [ ] Verify real-peer microphone/screen-audio gain, mute/deafen/PTT and device
  switching on macOS, Windows and Android hardware.
- [ ] Verify local share permission grants, OS-level stop, Android 14+
  MediaProjection service behavior and real-peer capture on each target.
- [ ] Complete viewer stream rail, fullscreen, quality/diagnostics and audio
  states against the web reference.

## P2 — Visual, keyboard and accessibility parity

- [ ] Compare the compact maintenance notice with the web banner at desktop
  and Android portrait sizes; narrow Flutter layout has widget coverage.
- [ ] Capture matched web/Flutter screenshots at 1440×900, 1280×800, 1024×768
  and Android portrait for auth, chat, DM, members, prejoin/voice, screen share,
  profile, audio and administration; track deviations by screen.
- [ ] Finish focus trapping/return, keyboard reachability and loading/error
  semantics for drawers, search, admin, profile and dialogs.
- [ ] Verify responsive breakpoints, resize behavior, accessibility labels and
  narrow layouts on macOS, Windows and Android.
- [ ] Compare navigation voice roster ordering, spacing, avatars and status
  indicators directly with the web client.

## P2 — Identity, profile and delivery gates

- [ ] Finish login/register/profile loading, validation, error and focus parity.
- [ ] Configure signed platform/domain association before claiming automatic
  password-reset URL opening.
- [ ] Decide and document native equivalents for browser-only profile
  notification preferences; do not show a nonfunctional toggle.
- [ ] Build and launch Windows on a Windows runner; test macOS and Android
  release builds/signing before release.
- [x] Generate a private persistent Android upload keystore and build a signed
  release APK. The local configuration and JKS are excluded from Git; the APK
  signer certificate matches the JKS (`evidence/android/qa13-release-signing-2026-09-26-001.json`).
- [ ] Back up the upload JKS and local signing credentials securely, then
  install/update and exercise the release APK on a physical Android device.
- [ ] Track Flutter's Kotlin Gradle Plugin warning for `flutter_webrtc`,
  `livekit_client` and `flutter_background` and verify compatibility before the
  next Flutter toolchain upgrade.

## Currently executing

- [ ] P1: add edit/delete conflict recovery and live backend checks for TEXT
  and DM sends; optimistic/failed rows and explicit retry are implemented.
- [ ] P1: verify audio device enumeration, switching and screen re-entry with
  real devices and a real voice room on macOS/Android.
- [ ] Delivery: back up the new Android upload key and run physical-device
  release acceptance; the signed APK build itself passes.
