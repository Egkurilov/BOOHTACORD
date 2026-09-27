# Flutter ↔ web parity plan

Vue (`frontend/src`) is the product reference. The Flutter clients for macOS,
Windows and Android must match its user-visible behavior, information
hierarchy, copy, states and design tokens while using the same API, realtime,
ACL and LiveKit contracts. Platform-specific window chrome and permission
prompts are outside the visual comparison; product controls and resulting
states are not.

## Current parity map

Status below reflects the Flutter and web source as of 2026-09-27, including native
identity/reset, audio/PTT, local screen publishing, and live voice navigation
slices. Reconcile this table
when a feature lands; do not use the old summary as a substitute for reading
the implementation.

| Area | Web reference | Flutter now | Remaining gap |
| --- | --- | --- | --- |
| Authentication and maintenance | `identity/AuthenticationLanding.vue`, `maintenance/MaintenanceBanner.vue`, `identity/PasswordResetCompletion.vue` | Login/register, server URL and secure session; compact maintenance banner; protected 401 clears private workspace; reset completion from pasted same-origin link | Automatic HTTPS app-link association, full focus/error and screenshot parity |
| Workspace shell | `workspace/WorkspaceApp.vue`, `WorkspaceMain.vue`, `useWorkspaceDrawers.ts` | Sidebar/member drawers and scrim on compact layouts; medium member overlay; wide member aside; search stays beside the active conversation; modal search overlay below 1280 px and in wide voice-stage layout; drawer/search focus scopes, Escape/close behavior and focus return | Exact breakpoint behavior, admin/profile/dialog focus, accessibility announcements and screenshot comparison |
| Profile | `identity/ProfileSettings.vue`, `workspace/WorkspaceUserFooter.vue` | Display name/password, authenticated private avatar rendering, PNG/JPEG upload/remove, logout flow with pending/error state | Exact loading/error/focus parity, notification settings |
| Channels | `channel/ChannelNavigation.vue`, `conversation/TextConversation.vue`, `text_read_gate.ts`, `voice_navigation_presence.ts` | Ordered categories, text/voice selection, caller-local unread/mention badges, newest visible message cursor advancement; active voice channel now shows live member count, mic/speaking status and screen-share indicators | Visual comparison of the expanded voice roster; admin topology controls are tracked under Administration |
| Text chat | `conversation/TextConversation.vue`, `TextHistoryList.vue`, `MessageItem.vue`, `MessageBody.vue` | Chronological cursor-paged history with scroll restoration; local-date dividers and same-author grouping; formatted bodies and safe HTTP(S) links; mention picker/sending/name display; send, reply target/preview, edit/delete and visible read cursor; optimistic/failed rows with explicit exact-payload retry reusing `client_message_id`, reconciled against server history; edit draft/mention preservation and targeted revision refresh after `409`; delete keeps the loaded window; deleted-during-edit and stale-conversation widget/state coverage | Native notification equivalent, live backend mutation/retry check and visual QA |
| Text attachments/search | `TextMessageAttachmentPicker.vue`, `TextMessageAttachments.vue`, `PublishedAttachmentCard.vue`, `ProtectedImageViewer.vue`, `TextMessageSearch.vue` | Native multi-file picker, 10 × 25 MB checks, authenticated multipart upload with per-file progress and retry preserving successful IDs; upload target captured before reading bytes; attachment-only send supported; web image clipboard paste joins the upload queue while text paste remains intact [QA-21](../evidence/flutter/qa21-clipboard-image-paste-2026-09-27-001.json); protected image viewer with zoom/loading/retry/unavailable states and separate platform save action; web and Flutter use separate open/save actions; channel-scoped search and context navigation | Verify image paste, protected download and ACL in an authenticated browser/device; native image clipboard support is still open [FE-56](../backlog/FRONTEND_TODO.md); verify server-side `UNATTACHED` cleanup and live 507/partial-upload UX [QA-20](../evidence/flutter/qa20-web-attachment-image-viewer-2026-09-27-001.json) |
| Direct messages | `direct_message/DirectMessageConversation.vue`, `DirectMessageNavigation.vue`, `DirectMessageAttachments.vue`, `PublishedAttachmentCard.vue`, `ProtectedImageViewer.vue`, `MessageBody.vue` | List/create/open, cursor-paged history with scroll restoration, send, unread/read cursor, edit/delete, formatted bodies and mention picker/name display; reply compose/preview; private attachments upload with per-file progress and retry preserving successful IDs, attachment-only send and web image clipboard paste into its conversation-scoped upload queue [QA-21](../evidence/flutter/qa21-clipboard-image-paste-2026-09-27-001.json); protected image viewer with zoom/loading/retry/unavailable states and separate save action; upload target captured before reading bytes; DM-scoped search/context; optimistic/failed rows with explicit exact-payload retry keep the original `client_message_id` and stay in their DM; edit draft/mention preservation and targeted revision refresh after `409`; delete keeps the loaded window | Native image clipboard support [FE-56](../backlog/FRONTEND_TODO.md), native notification equivalent, verify server-side `UNATTACHED` cleanup and live 507/partial-upload UX, live backend mutation/retry check, ACL and visual QA [QA-20](../evidence/flutter/qa20-web-attachment-image-viewer-2026-09-27-001.json) |
| Members and presence | `workspace/WorkspaceMembersPanel.vue`, `MemberPopover.vue`, `identity/guild_presence.ts` | Directory, online/offline/unknown, profile dialog with same-voice volume control, start DM, avatars | Web presence grouping/refresh states and richer anchored popover design |
| Voice connection | `voice/VoicePrejoin.vue`, `VoiceDock.vue`, `connection_store.ts`, `VoiceParticipantVolumes.vue`, `voice_roster_client.ts` | Join/transfer, listener-only join, mic mute, deafen, leave, participant status cards, visible reconnect state and lease-specific revocation reasons; authenticated voice roster is polled every 10 seconds and shown in the prejoin card/navigation without creating a voice lease; per-participant microphone volume 0–200% with account-scoped local preferences; PTT holds mic open and releases safely on key-up/focus loss/teardown | Verify live roster refresh/privacy failure and real-peer gain/PTT on each platform, bounded reconnect parity, permission-denied parity and exact dock state/copy [QA-18](../evidence/flutter/qa18-prejoin-voice-roster-2026-09-27-001.json) |
| Audio settings | `voice/AudioSettings.vue`, `activation_store.ts`, `audio_settings_store.ts` | Account settings panel with input/output device selection, account-scoped persistence, VAD/PTT and key assignment, AGC/echo/noise controls; native device labels remain visible even without a `default` entry, the panel follows device-change events without stale scans, and device enumeration is retried after the first successful microphone capture in case labels were permission-gated; Android has a visible Back control and handles system Back from audio/profile/admin panels; avoids claiming native effective processing state that SDK does not expose | Verify actual device enumeration, hotplug and switching/processing audibly on macOS/Windows/Android; PTT hold/release and focus/state visual comparison |
| Screen sharing | `voice/ScreenViewer.vue`, `ScreenDiagnosticsPanel.vue`, `screen_viewer_controller.ts`, `screen_client_reporter.ts` | Remote stream selection/viewer basics; viewer rail can switch between local preview and remote streams with an accessible selected state; remote receiver diagnostics sample decoded frames, bitrate, loss and jitter every two seconds, with unavailable RTT shown truthfully; native viewer has a fullscreen overlay, Escape/exit control, spaced diagnostics and explicit receiver-stat read status; screen-audio level 0–200% with account-scoped local preference and truthful no-audio/deafened states; local desktop picker/publish/stop and Android MediaProjection foreground service; own published screen can be reopened from the participant card; Android sends bounded anonymous sender FPS/bitrate/RTT while sharing [QA-19](../evidence/flutter/qa19-android-sender-metrics-2026-09-27-001.json) | Verify populated metrics on each platform, sender/receiver correlation, reopen and OS-level stop with a real share, permissions, fullscreen parity and playback/gain; matched screenshots remain open [QA-17](../evidence/flutter/qa17-voice-viewer-mobile-navigation-2026-09-27-001.json) |
| Search | `search/WorkspaceSearchPanel.vue`, `SearchPanel.vue`, chat search components | Global/channel/DM search in a responsive side panel while preserving the active conversation; modal overlay below 1280 px with scrim and closed-loop keyboard focus; cursor pagination; server-centered context and return to origin; stale topology refresh; Ctrl/Cmd+K, Escape and search-focus restoration; loading/error/empty announcements | Matched web screenshots, device screen-reader acceptance and parity for less common loading/error states |
| Administration | `workspace/AdminPanel.vue`, `channel/AdminTopologyControls.vue`, `AdminMembersSection.vue`, `AdminAuditSection.vue` | Admin-only Members/Channels/Audit tabs; cursor-paginated directory with preserved role/block drafts and save; per-row focus restoration and accessible error/success; expiring reset-link result/copy/close; same-voice admin kick; category/channel mutations and confirmations; cursor-paged audit without message content; widget coverage for member pagination/save failures, reset-link lifecycle and audit empty/error/refresh | Loading-state accessibility/visual parity, conflict recovery, live REST ACL verification, overall screenshot comparison |

## Delivery sequence

### 0. Baseline and acceptance map — in progress

- Map every web route/panel, visible control, state transition, API call and ACL
  rule to Flutter.
- Keep the parity table above current and link each gap to its source components
  and contract operation.
- Capture web reference screenshots for signed-out, text chat, DM, member
  drawer, voice prejoin, active voice, screen viewer, profile, audio and admin.
- Record common viewport sizes: 1440×900, 1280×800, 1024×768 and Android
  portrait. Use the same account/data in both clients.

### 1. Design foundation and workspace shell — in progress

- Port every value from `frontend/src/design/tokens.css` into Flutter colors,
  spacing, typography, radii, control sizes and layout breakpoints.
- Match shell columns and frame geometry at wide, medium and compact widths.
- Implement web-equivalent responsive navigation/member/search drawers,
  scrim, escape/close behavior, focus return and keyboard reachability. Navigation
  and member drawers preserve the active channel/voice view behind a scrim;
  compact and medium widths use overlays while wide layouts retain the member
  aside. Drawer overlays now own a closed-loop focus scope, exclude the covered
  workspace from keyboard traversal and restore the opening focus on close.
  Search remains beside the conversation on wide layouts and uses a trapped,
  scrim-backed right panel below 1280 px and over wide voice stages. Search
  Ctrl/Cmd+K launch, Escape close, focus return and live loading/error/empty
  announcements are implemented. Exact breakpoints, other panel focus and
  screenshot comparison remain open.
- Match header, channel navigation, selected/hover/focus states, user footer,
  member aside and voice dock sizes and copy.

### 2. Identity and account settings

- Maintenance state now polls the public `/maintenance` contract every 5s and
  displays the shared banner above both guest and workspace screens; transient
  polling errors stay non-blocking and clear the banner like web.
- Protected REST 401s now clear the local cookie and private workspace; an
  invalid login response is excluded from this path. On realtime disconnect,
  Flutter verifies `/auth/session` before retrying, so network outages retry
  without signing out while expired sessions return to the guest screen.
- Native clients now accept a pasted reset URL, validate HTTPS/same-origin/path,
  extract the 43-character fragment token only into memory, clear the entry
  field, and submit it in the request body. Terminal results return to login
  with focus; automatic OS opening of the HTTPS URL remains open until domain
  association is configured for actual platform signing identities.
- Match login/register validation, server configuration and remaining
  web-equivalent focus/error states.
- Profile avatar upload/delete now use the caller-only `/me/avatar` contract,
  native file selection, PNG/JPEG signature validation and the 2 MiB cap. Name
  and password updates already have client validation and saved/error feedback.
- Logout section/flow now stops voice, only clears local authenticated state
  after server-confirmed revocation, and preserves the cookie for retry on
  failure. Still match profile loading/error/focus states.
- Web notifications are local browser-only preferences backed by Notification
  permission, local storage and Web Locks deduplication; there is no server
  notification contract. A native desktop equivalent needs a separate
  platform-aware design before adding controls (never show a fake toggle).
- Automatic OS delivery of the reset URL remains open. The native paste flow
  does not persist or log the token and sends it only in the request body.

### 3. Channel navigation and administration

- Text channel unread and mention counts now parse from the authenticated
  topology response and render only for TEXT channels. Empty categories match
  the web copy. Opening a channel scrolls to latest and advances the caller's
  monotonic read cursor to the newest rendered message intersecting the
  conversation viewport only while the app is foregrounded; scrolling older
  cannot regress it, and successful advancement reloads server counts.
- Connected voice navigation now mirrors live member count and roster status
  (mic, speaking and screen sharing) from LiveKit events; focused comparison of
  roster ordering/spacing remains. Connected rooms also render participant
  cards and mic/speaking status; remaining lifecycle gaps are tracked in phase 6.
- Port admin topology operations with confirmations, revision conflicts and
  refresh recovery. Initial slice now adds authenticated category/channel
  create/rename and empty-category deletion, admin-only entry, server-side
  authorization, confirmation before category deletion, and refresh after
  stale-topology conflicts. Category/channel ordering and channel movement now
  send the current topology revision and refresh after mutation/conflict. TEXT
  archive and VOICE admission close now use the expected-revision contracts and
  web-equivalent confirmations. Voice close copy explicitly says SFU media
  revocation is pending; a revoked-lease count is not described as a confirmed
  disconnect. The audit tab now uses the opaque `before` cursor and matches the
  web event-title/actor/target presentation without message content. Admin
  members now use the 100-item account cursor, per-row role/block drafts,
  save, focus restoration, one-time reset-link display/copy/close and same-voice
  kick contract. Widget coverage exercises account pagination, retained drafts
  on save failure, focus after success/failure, reset-link expiry/copy/close and
  audit empty/error/refresh states. Conflict recovery, comprehensive role/ACL
  integration checks, loading accessibility and screenshot parity remain open.

### 4. Text conversations

- Same-author grouping, local-date separators and message-body formatting now
  follow the web rules. Flutter supports paragraphs, bold, italic, inline code,
  fenced code and clickable HTTP(S) links; unsafe link schemes stay plain text.
  Mention IDs are parsed and resolved to member names in TEXT and DM history.
  Same-author grouping uses:
  same author, no reply/deleted boundary, same local date, and a gap of at most
  five minutes. History remains chronological and visible-message read tracking
  still keys only message rows. Older history now loads from the server cursor,
  deduplicates rows and restores the viewport offset after prepending. Reply
  actions now set/cancel a scoped composer
  target, send `reply_to_id`, render a preview, and jump to the referenced row
  when it is loaded. DM reply preview uses the server's `reply_preview` contract
  (or local history as fallback). History-to-specific-message context jumps,
  author directory coverage and screenshot comparison remain.
- Mention picker now submits selected IDs with the message; DM choices are
  limited to the conversation participant. Native notification behavior needs
  a separate platform-aware design. Optimistic rows and explicit send retries
  are implemented; edit revision conflicts now keep the draft, refresh only
  the target revision and allow another explicit save without dropping loaded
  history. Delete updates the loaded row locally. Live backend checks remain.
- Attachment picker/upload, 10-file/25 MB limits, send binding, private image
  preview and native save flow now work on desktop and Android. Multipart bytes
  report per-file progress; failed files can be retried without discarding
  successful IDs, and conversation switching cannot redirect selected bytes.
  Images open in an authenticated native viewer with zoom, loading, transient
  error retry and deleted/unavailable states; saving remains a separate action.
  Verify the existing 24-hour server-side unattached cleanup, live 507 handling,
  attachment ACL and visual comparison on devices.
- Channel/DM search, result context and return-to-origin are implemented with
  cursor pagination and an `at=<messageId>` history request. The search panel
  now keeps the conversation visible, follows responsive modal/aside behavior,
  traps focus only when modal, and announces loading/error/empty states. Compare
  its screenshots and screen-reader output on devices. Ctrl/Cmd+K is ignored
  while an editable text field owns focus; Escape closes the search panel and
  restores focus to the launcher (reopening compact navigation when necessary).

### 5. Direct messages and unified search

- Match candidate discovery, navigation badges, read cursor and realtime
  delivery. Cursor pagination and scroll restoration are now implemented.
- Reply compose/preview, participant-only mention picker, attachment upload and
  private preview/save, plus edit/delete are implemented with participant ACLs;
  add per-file retry/progress and send/conflict recovery.
- Global search and conversation-scoped context navigation are implemented;
  Ctrl/Cmd+K, Escape and launcher focus restoration are implemented and covered
  by widget tests; responsive modal search traps focus below 1280 px, while the
  wide side panel leaves the conversation and navigation available. Visual and
  screen-reader comparison remain.

### 6. Members and voice lifecycle

- Match member presence groups, anchored profile popover and DM entry.
- Voice participant cards now expose a 0–200% microphone control. The level is
  stored by signed-in account and remote account, preserves any saved screen
  level, and is reapplied when a track subscribes or the room reconnects.
  Verify actual gain with two real peers on macOS, Windows and Android.
  The member profile dialog also exposes
  this level for members in the same voice room; its anchored popover geometry
  still differs from web.
- Listener-only join now follows the web prejoin action and connects without
  enabling the microphone; regular join retains its mic-permission fallback.
  Explicit transfer is a separate action. LiveKit reconnect/resume events now
  surface a reconnecting state, preserve the current mic state and temporarily
  disable mic/deafen controls. Terminal disconnects clear local state and
  release the lease. Realtime lease revocation now validates both the active
  lease ID and the known reason, including revocation arriving during join, and
  displays the web-equivalent reason. The SDK still owns reconnect retry
  policy; implement bounded retry parity, permission-denied copy and remaining
  dock states.
- Match dock/prejoin/active/reconnecting/error states and their accessible labels.

### 7. Audio and screen sharing

- Native audio settings are now reachable from account settings and expose
  input/output device selection plus account-scoped saved device IDs and
  processing toggles (AGC, echo cancellation, noise suppression). Selection
  routes through LiveKit/native audio APIs; active local tracks receive device
  and runtime processing changes. The UI explicitly says the native SDK does
  not report effective processing state, rather than claiming the requested
  value was applied. Verify device switching and processing audibly on
  macOS/Windows/Android. VAD/PTT mode and account-scoped key assignment are
  implemented. PTT mutes on join and key release and is force-released on app
  backgrounding, desktop window blur, or voice teardown; text-entry, dialog and
  capture focus do not accidentally transmit. Verify hold/release and focus
  recovery with hardware keyboards on each target platform.
- Local screen picker/publish/stop is implemented for connected voice rooms;
  desktop uses LiveKit's screen/window picker, while Android requests the
  native MediaProjection grant and runs its declared `mediaProjection`
  foreground service with a sharing notification. Android intentionally does
  not request battery-optimization exemptions. Local capture is shown as a
  preview and can be stopped from the voice header; stopping on the OS side is
  reflected by LiveKit's track-unpublished event. Native screen audio is not
  supported by the current capture API, so local screen shares are video-only.
  Verify OS-level stop, Android 14+ permission/service behavior, and real-peer
  capture on macOS, Windows and Android.
- Match viewer stream rail, explicit selection, fullscreen, screen audio/volume,
  quality controls and diagnostics. The remote audio slider now follows the
  selected stream's account-scoped preference and distinguishes absent audio
  from deafen; verify actual playback/gain on each target platform.
- Keep platform-specific permission prompts native while preserving the same
  in-app flow and recovery copy.

### 8. Parity gate and release

- Compare reference and Flutter screenshots at the same viewport and data;
  track geometry/color/type deviations per screen.
- Exercise every control and non-happy state against the same backend contracts.
- Check keyboard/focus, accessibility labels, narrow layouts and window resize
  behavior on macOS, Windows and Android.
- Current local verification now covers macOS debug and Android debug builds.
  Windows still requires a native Windows build runner; do not infer it from
  analyzer/tests or generated plugin registration.
- Android debug build succeeds but reports that `flutter_webrtc` and
  `livekit_client` currently apply the Kotlin Gradle Plugin, which Flutter warns
  will become incompatible with a future Flutter release. Track their upstream
  migration/upgrade before that toolchain change.
- Do not mark a row complete until both the feature and its visual/state parity
  criteria have evidence.

## First implementation slices

The shell pass ports the design tokens and aligns geometry with
`frontend/src/design/shell.css` and `responsive_shell.css`: wide navigation and
member columns, medium widths, frame inset, border and shell radius. Responsive
drawers and search panel are implemented, including scrim, modal focus trapping
and restoration; exact breakpoints, typography and per-screen screenshot
comparison remain open in phase 1.
The identity slice adds caller-only avatar upload/delete, logout failure
semantics, maintenance status and pasted one-use password-reset links. Channel
navigation now carries text-only unread/mention counts and a foreground read
cursor based on the newest visible message. Text history now groups eligible
same-author messages, inserts local-date dividers and renders web-compatible
body formatting, member-name mention picker and mention IDs in TEXT/DM history;
HTTP(S) links open through the platform. TEXT and DM attachments now support
native picking, authenticated upload, sending, protected preview and saving.
Voice prejoin now includes a listener-only action and explicit
transfer action; active rooms render participant cards/status and remote screen
viewing. Search now spans all conversations or the active channel/DM, opens
server-centered context and returns to the originating conversation in a
responsive side panel that preserves the active conversation. Screenshot and
device screen-reader comparison, real-peer voice/screen-audio gain and PTT
verification, bounded reconnect retry policy, native notification behavior,
attachment cleanup, admin member actions and Windows-native build verification
remain open. Local screen publishing now has desktop/Android controls and
Android foreground-service plumbing, but still needs OS-level and real-peer
verification. Live voice navigation refreshes its roster from participant,
track and speaker events. Lease-specific revocation and visible reconnect
states are implemented, but still need backend-driven integration coverage and
screenshot comparison.
