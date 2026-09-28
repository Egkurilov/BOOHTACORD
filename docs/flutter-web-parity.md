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
| Authentication and maintenance | `identity/AuthenticationLanding.vue`, `maintenance/MaintenanceBanner.vue`, `identity/PasswordResetCompletion.vue` | Auth page follows web eyebrow/title/copy, 440 px max card, responsive padding, labeled fields and full-width submit [QA-42](../evidence/flutter/qa42-auth-layout-web-parity-2026-09-28-001.json); login accepts a nonempty existing password while registration enforces the backend's 12–128 Unicode-code-point range [QA-43](../evidence/flutter/qa43-auth-password-validation-web-contract-2026-09-28-001.json); switching login/register clears the prior auth error as on web [QA-44](../evidence/flutter/qa44-auth-mode-error-reset-2026-09-28-001.json); stable Android focus nodes/field keys and no login autocorrect/suggestions; native server/reset actions retained; maintenance banner follows web min-height 44, 14/20 text, 12/16 padding and natural wrapping [QA-41](../evidence/flutter/qa41-maintenance-banner-web-geometry-2026-09-28-001.json); protected 401 clears private workspace; reset completion from pasted same-origin link [QA-23](../evidence/flutter/qa23-android-ime-screen-share-2026-09-27-001.json) | Confirm first-character/multi-character Gboard entry on Samsung; automatic HTTPS app-link association, full focus/error and screenshot parity |
| Workspace shell | `workspace/WorkspaceApp.vue`, `WorkspaceMain.vue`, `useWorkspaceDrawers.ts` | Sidebar/member drawers and scrim on compact layouts; medium member overlay; wide member aside; search stays beside the active conversation; modal search overlay below 1280 px and in wide voice-stage layout; drawer/search focus scopes, Escape/close behavior and focus return | Exact breakpoint behavior, admin/profile/dialog focus, accessibility announcements and screenshot comparison |
| Profile | `identity/ProfileSettings.vue`, `identity/current_profile.ts`, `workspace/WorkspaceUserFooter.vue` | Display name/password, authenticated private avatar rendering, PNG/JPEG upload/remove, logout flow with pending/error state; profile load failures are isolated from general workspace errors, with accessible loading/error live-region states and retry-clearing behavior [QA-45](../evidence/flutter/qa45-profile-loading-error-web-parity-2026-09-28-001.json); own-profile validation now matches web/backend Unicode code-point rules without trimming display names or applying a grapheme-count input cap; mutation feedback is announced, and opening the profile focuses its semantic heading [QA-48](../evidence/flutter/qa48-profile-mutation-validation-focus-web-parity-2026-09-28-001.json); layout follows web CSS max-width 720/480, centered/responsive insets, 64 px avatar, 16 px title and section separators; panel toolbar has one semantic page heading and breakpoint-matched actions [QA-49](../evidence/flutter/qa49-profile-geometry-web-parity-2026-09-28-001.json); native macOS/Windows/Android notification preference uses generic previews, OS permission handling, hidden-app delivery, unread increase and per-account deduplication [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json) | Matched screenshots; Samsung/Gboard and real screen-reader keyboard acceptance; real macOS notification permission/delivery, Windows toast registration, and Android 13+ permission/background delivery acceptance |
| Channels | `channel/ChannelNavigation.vue`, `conversation/TextConversation.vue`, `text_read_gate.ts`, `voice_navigation_presence.ts`, `voice/VoiceRoomRoster.vue` | Ordered categories, text/voice selection, caller-local unread/mention badges, newest visible message cursor advancement; active voice channel now shows live member count, mic/speaking status and screen-share indicators; prejoin/connected rosters now match web's 24 px avatars, 12 px labels, 4 px row gaps, 40 px indent, FNV palette mapping, and outlined screen-share badge [QA-36](../evidence/flutter/qa36-voice-roster-web-geometry-2026-09-28-001.json) | Matched screenshots and runtime comparison of active/prejoin roster at desktop breakpoints and Android portrait; admin topology controls are tracked under Administration |
| Text chat | `conversation/TextConversation.vue`, `TextHistoryList.vue`, `MessageItem.vue`, `MessageBody.vue` | Chronological cursor-paged history with scroll restoration; local-date dividers and same-author grouping; formatted bodies and safe HTTP(S) links; mention picker/sending/name display; send, reply target/preview, edit/delete and visible read cursor; optimistic/failed rows with explicit exact-payload retry reusing `client_message_id`, reconciled against server history; edit draft/mention preservation and targeted revision refresh after `409`; delete keeps the loaded window; deleted-during-edit and stale-conversation widget/state coverage; native generic notifications fire only for new unread messages while app is hidden [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json) | Live backend mutation/retry check, native notification OS delivery acceptance and visual QA |
| Text attachments/search | `TextMessageAttachmentPicker.vue`, `TextMessageAttachments.vue`, `PublishedAttachmentCard.vue`, `ProtectedImageViewer.vue`, `TextMessageSearch.vue` | Native multi-file picker, 10 × 25 MB checks, authenticated multipart upload with per-file progress and retry preserving successful IDs; upload target captured before reading bytes; attachment-only send supported; web paste plus native Flutter `Ctrl/Cmd+V`, `Shift+Insert`, context menu and explicit paste action read clipboard PNG into the scoped upload queue while preserving plain text [QA-21](../evidence/flutter/qa21-clipboard-image-paste-2026-09-27-001.json), [QA-22](../evidence/flutter/qa22-native-clipboard-image-paste-2026-09-27-001.json); protected image viewer with zoom/loading/retry/unavailable states and separate platform save action; web and Flutter use separate open/save actions; channel-scoped search and context navigation | Run native paste/permission/size acceptance on macOS, Windows and Android; compile on a Windows runner; verify protected download/ACL, server-side `UNATTACHED` cleanup and live 507/partial-upload UX [QA-20](../evidence/flutter/qa20-web-attachment-image-viewer-2026-09-27-001.json) |
| Direct messages | `direct_message/DirectMessageConversation.vue`, `DirectMessageNavigation.vue`, `DirectMessageAttachments.vue`, `PublishedAttachmentCard.vue`, `ProtectedImageViewer.vue`, `MessageBody.vue` | List/create/open, cursor-paged history with scroll restoration, send, unread/read cursor, edit/delete, formatted bodies and mention picker/name display; reply compose/preview; private attachments upload with per-file progress and retry preserving successful IDs, attachment-only send, web/native clipboard paste and explicit retry into the conversation-scoped upload queue [QA-21](../evidence/flutter/qa21-clipboard-image-paste-2026-09-27-001.json), [QA-22](../evidence/flutter/qa22-native-clipboard-image-paste-2026-09-27-001.json); protected image viewer with zoom/loading/retry/unavailable states and separate save action; upload target captured before reading bytes; DM-scoped search/context; optimistic/failed rows with explicit exact-payload retry keep the original `client_message_id` and stay in their DM; edit draft/mention preservation and targeted revision refresh after `409`; delete keeps the loaded window; new unread DMs use generic native notifications [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json) | Run native paste/retry permission acceptance on macOS, Windows and Android; compile on a Windows runner; verify server-side `UNATTACHED` cleanup and live 507/partial-upload UX, live backend mutation/retry check, notification OS delivery, ACL and visual QA [QA-20](../evidence/flutter/qa20-web-attachment-image-viewer-2026-09-27-001.json) |
| Members and presence | `workspace/WorkspaceMembersPanel.vue`, `GuildPresenceGroup.vue`, `MemberPopover.vue`, `identity/guild_presence.ts` | Directory grouped into online/offline/unknown sections with matching counts and inline loading/error/retry states; realtime snapshots and changes update group membership, while an unavailable feed resolves every status to unknown until a new snapshot; anchored profile popover loads authenticated member details and exposes DM, same-voice volume, and admin voice kick actions [QA-27](../evidence/flutter/qa27-member-presence-groups-2026-09-27-001.json), [QA-28](../evidence/flutter/qa28-guild-presence-realtime-2026-09-27-001.json), [QA-29](../evidence/flutter/qa29-member-profile-popover-2026-09-27-001.json); responsive popover width, right inset, row alignment, avatar and action/volume geometry now follow web CSS tokens [QA-34](../evidence/flutter/qa34-member-profile-popover-web-geometry-2026-09-28-001.json) | Verify live presence transitions against two accounts; matched visual/device acceptance for roster and popover |
| Voice connection | `voice/VoicePrejoin.vue`, `VoiceDock.vue`, `connection_store.ts`, `VoiceParticipantStatus.vue`, `VoiceParticipantVolumes.vue`, `voice_roster_client.ts` | Join/transfer, listener-only join, mic mute, deafen, leave, participant status cards, visible reconnect state and lease-specific revocation reasons; dock now follows web connected/reconnecting/leaving copy and state-specific hints, announces transitions, serializes deafen operations and locks pending/leave controls [QA-53](../evidence/flutter/qa53-voice-dock-deafen-web-parity-2026-09-28-001.json); authenticated voice roster is polled every 10 seconds and shown in the prejoin card/navigation without creating a voice lease; prejoin and joining copy now match web, with live-region announcements for connection and failure states [QA-52](../evidence/flutter/qa52-voice-prejoin-copy-live-region-2026-09-28-001.json); per-participant microphone volume 0–200% with account-scoped local preferences; PTT holds mic open and releases safely on key-up/focus loss/teardown; failed microphone capture visibly identifies the listener fallback, marks the local participant unavailable and offers VAD retry without bypassing PTT [QA-32](../evidence/flutter/qa32-voice-microphone-unavailable-fallback-2026-09-27-001.json); active room recovery is capped at the web policy's six attempts and releases the lease after exhaustion [QA-33](../evidence/flutter/qa33-flutter-voice-reconnect-limit-2026-09-28-001.json); participant status precedence and speaking indicators now match web for muted, unavailable, deafened, speaking and in-channel states [QA-35](../evidence/flutter/qa35-voice-participant-status-web-parity-2026-09-28-001.json) | Verify live roster refresh/privacy failure and real-peer gain/PTT on each platform; Flutter SDK backoff intervals still differ from web; validate reconnect timing, actual mute/deafen media and screen-reader announcements on native hardware, and exact dock/prejoin visual comparison [QA-18](../evidence/flutter/qa18-prejoin-voice-roster-2026-09-27-001.json) |
| Audio settings | `voice/AudioSettings.vue`, `activation_store.ts`, `audio_settings_store.ts` | Account settings panel with input/output device selection, account-scoped persistence, VAD/PTT and key assignment, AGC/echo/noise controls; native device labels remain visible even without a `default` entry, the panel follows device-change events without stale scans, manual refresh stays enabled after enumeration completes and reflects pending state, and device enumeration is retried after the first successful microphone capture in case labels were permission-gated; Android has a visible Back control and handles system Back from audio/profile/admin panels; avoids claiming native effective processing state that SDK does not expose | Verify actual device enumeration, hotplug and switching/processing audibly on macOS/Windows/Android; PTT hold/release and focus/state visual comparison |
| Voice stream-start alert | `voice/VoiceDock.vue`, `stream_start_runtime.ts`, `stream_start_alert.ts`, `stream_start_chime.ts` | Newly started remote shares show a six-second live-region dock notice and a persisted, toggleable sound signal; initial room baseline and reconnect tracking avoid duplicate alerts for existing/restored shares [QA-54](../evidence/flutter/qa54-voice-stream-start-alert-web-parity-2026-09-28-001.json) | Verify LiveKit event timing and audible platform system sound on macOS, Windows and Android |
| Screen sharing | `voice/ScreenViewer.vue`, `ScreenDiagnosticsPanel.vue`, `screen_viewer_controller.ts`, `screen_client_reporter.ts` | Remote stream selection/viewer basics; viewer rail can switch between local preview and remote streams with an accessible selected state; remote receiver diagnostics sample decoded frames, bitrate, loss and jitter every two seconds, with unavailable RTT shown truthfully; native viewer has a fullscreen overlay, Escape/exit control, spaced diagnostics and explicit receiver-stat read status; anonymous sender/receiver reports and admin diagnostics include bounded encoded/received frame width and height for source-versus-peer comparison [QA-50](../evidence/flutter/qa50-screen-share-frame-dimensions-2026-09-28-001.json); screen-audio level 0–200% with account-scoped local preference and truthful no-audio/deafened states; custom source picker previews/screens/windows and explicit selection on desktop; resolution and frame-rate selection supports 720/1080/1440p at 15/30/60 FPS, displays estimated bandwidth, and applies capture/encoding parameters; Android compact layout keeps quality labels on one line and stacks them above full-width selectors, with a scrollable setup body and fixed action footer at 360 dp [QA-31](../evidence/flutter/qa31-android-share-quality-compact-layout-2026-09-27-001.json); Android shows setup and permission guidance without a desktop source list [QA-24](../evidence/flutter/qa24-screen-share-quality-picker-2026-09-27-001.json); Android publication cleans up an unpublished capture track on failure and surfaces SDK detail [QA-23](../evidence/flutter/qa23-android-ime-screen-share-2026-09-27-001.json); own published screen can be reopened from the participant card; Android sends bounded anonymous sender FPS/bitrate/RTT while sharing [QA-19](../evidence/flutter/qa19-android-sender-metrics-2026-09-27-001.json) | Verify source enumeration/thumbnail updates and real encoder/network load across profiles; successful/retried Android capture, populated metrics on each platform, sender/receiver correlation, reopen and OS-level stop with a real share, permissions, fullscreen parity and playback/gain; matched screenshots remain open [QA-17](../evidence/flutter/qa17-voice-viewer-mobile-navigation-2026-09-27-001.json) |
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
  notification contract. Flutter now has platform-aware local notification
  preferences and generic previews without message content [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json);
  OS permission/delivery acceptance on physical macOS, Windows and Android
  remains open.
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
  Native clipboard PNG paste is now wired through the same queue with
  `Ctrl/Cmd+V`, `Shift+Insert`, a context-menu action and a visible paste
  control. Co-pasted plain text is inserted at the current selection; clipboard
  reads happen only after an explicit paste action. Widget tests cover the
  TEXT/DM scope, limits and retry; real clipboard/permission acceptance remains.
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
- Reply compose/preview, participant-only mention picker, attachment upload,
  private preview/save and scoped native clipboard paste, plus edit/delete are
  implemented with participant ACLs; add device acceptance for private upload,
  retry/progress and send/conflict recovery.
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
  this level for members in the same voice room. Its anchored popover now uses
  the web's responsive aside width, 16 px right inset, row-top alignment, avatar,
  identity typography and 40 px full-width actions; the volume percentage is
  separated from its label as in the web grid
  [QA-34](../evidence/flutter/qa34-member-profile-popover-web-geometry-2026-09-28-001.json).
- Listener-only join now follows the web prejoin action and connects without
  enabling the microphone; regular join retains its mic-permission fallback.
  When microphone capture fails, Flutter now explicitly marks the local
  participant as unavailable, explains that the room was joined as a listener,
  and offers a retry. Push-to-talk mode instead asks for the assigned key to be
  held, so retry never opens the microphone outside the user's PTT gesture
  [QA-32](../evidence/flutter/qa32-voice-microphone-unavailable-fallback-2026-09-27-001.json).
  Explicit transfer is a separate action. LiveKit reconnect/resume events now
  surface a reconnecting state, preserve the current mic state and temporarily
  disable mic/deafen controls. Terminal disconnects clear local state and
  release the lease. The Flutter client now ends active-room recovery after
  the same six retries as web and releases the lease with retry guidance;
  retry intervals are still owned by the native SDK and differ from web
  [QA-33](../evidence/flutter/qa33-flutter-voice-reconnect-limit-2026-09-28-001.json).
  Participant status labels and speaking indicators now share the web priority:
  deafen, unavailable microphone, muted, speaking, then in-channel. All active
  voice representations suppress speaking when the microphone is unavailable,
  muted or deafened [QA-35](../evidence/flutter/qa35-voice-participant-status-web-parity-2026-09-28-001.json).
  Realtime lease revocation now validates both the active
  lease ID and the known reason, including revocation arriving during join, and
  displays the web-equivalent reason. Align native retry delays with web and
  verify reconnect runtime behavior on real peers; permission-denied and
  remaining dock/device states also need platform acceptance.
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
  from deafen. The selectable stream rail now sits below the video stage rather
  than obscuring its lower edge; stream cards follow the web avatar/name/status/
  audio/selected-marker layout and expose track availability to assistive tech
  [QA-37](../evidence/flutter/qa37-voice-viewer-rail-web-parity-2026-09-28-001.json).
  If a selected remote screen disappears, Flutter now retains a distinct ended
  state and waits for an explicit selection or return-to-participants action;
  it does not silently fall back to the local share
  [QA-38](../evidence/flutter/qa38-voice-screen-ended-state-2026-09-28-001.json).
  Viewer selection state is keyed to its voice-channel ID, preventing a stream
  identity or ended-state from leaking into another room
  [QA-39](../evidence/flutter/qa39-voice-channel-viewer-scope-2026-09-28-001.json).
  Verify actual playback/gain and matched viewer screenshots on each target
  platform.
- Keep platform-specific permission prompts native while preserving the same
  in-app flow and recovery copy.

### 8. Parity gate and release

- A fresh macOS debug launch exposed a legacy Keychain stall: the native sample
  showed `flutter_secure_storage` blocked in `SecItemCopyMatching` while
  `SecurityServer` decrypted a legacy item. macOS now uses the Data Protection
  Keychain; debug startup reaches the signed-out login screen. Verify signed
  release persistence and the one-time re-login behavior for legacy cookies
  [QA-40](../evidence/flutter/qa40-macos-startup-loading-2026-09-28-001.json).
- Compare reference and Flutter screenshots at the same viewport and data;
  track geometry/color/type deviations per screen.
- Exercise every control and non-happy state against the same backend contracts.
- Check keyboard/focus, accessibility labels, narrow layouts and window resize
  behavior on macOS, Windows and Android.
- Local verification covers macOS debug/release builds and Android debug; the
  Android release APK also builds with the configured upload key, passes APK
  Signature Scheme v2 verification and contains notification/MediaProjection
  permissions [QA-47](../evidence/flutter/qa47-android-release-apk-signing-2026-09-28-001.json).
  Signed macOS release persistence and Android install/runtime acceptance on a
  physical device remain open.
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
verification, bounded reconnect retry policy, native notification OS delivery,
attachment cleanup, admin member actions and Windows-native build verification
remain open. Local screen publishing now has desktop/Android controls and
Android foreground-service plumbing, but still needs OS-level and real-peer
verification. Live voice navigation refreshes its roster from participant,
track and speaker events. Lease-specific revocation and visible reconnect
states are implemented, but still need backend-driven integration coverage and
screenshot comparison.
