# BOOHTACORD Design V2 Full Implementation Plan

> **For agentic workers:** Execute this plan inline in the current task, one focused packet at a time. Preserve the current Vue stores and API boundaries.

**Goal:** Match all 30 live HTML handoff states R01–R30 to the real BOOHTACORD Web application, plus the responsive/derived component states explicitly covered by the implementation spec, while preserving production message, ACL, and media behavior.

**Architecture:** Keep the existing Vue composition: `WorkspaceApp` → `WorkspaceMain` → `ConversationPane` → `TextConversation` → `TextHistoryList` / `MessageItem` / `PublishedAttachmentCard`. Port design tokens and visual rules only from the supplied handoff into CSS loaded by the existing app; use the handoff’s demo pages solely as visual references. Add no demo application data or alternate application runtime.

**Tech Stack:** Vue 3, TypeScript, Vite, CSS custom properties, Vitest, Playwright Chromium.

---

## Route and baseline

- Workflow class: `split_first`; task size: large.
- Selected leaf: Web conversation presentation (R01 desktop, R02 mobile, R03 tablet) plus shared design primitives it consumes.
- Native manifest: `clients/web/package.json`; CSS composition entry: `clients/web/src/style.css`.
- Runtime edge: `WorkspaceApp.vue` renders `WorkspaceMain.vue`; `WorkspaceMain.vue` renders `ConversationPane.vue`; channel chat uses `TextConversation.vue`, which composes `TextHistoryList.vue`, `MessageItem.vue`, and `PublishedAttachmentCard.vue`.
- Existing behavior to preserve: server-backed channels and presence, role/permission filtering, message grouping, reply and tombstone rows, pending/retry state, attachment preview and authorized download, composer keyboard/IME behavior, scroll anchor/read cursor, and LiveKit session ownership.
- Baseline: four focused design test files passed, 23 tests passed before edits. Initial Vitest attempt required installing the exact lockfile dependencies with `npm ci`.
- Source package: `BOOHTACORD_DESIGN_V2_LIVE_HTML_SOURCE_2026-10-03/BOOHTACORD_DESIGN_V2_HTML`; read its README, manifest, token sources, and R01–R03. The package explicitly identifies its actions and data as synthetic, so do not port `demo.js` or generated mock records.

## Existing-to-reference component map

| Reference region | Existing production owner | Implementation boundary |
|---|---|---|
| App frame, guild sidebar, mobile nav | `WorkspaceApp.vue`, `WorkspaceSidebarTabs.vue`, `WorkspaceUserFooter.vue` | CSS and existing semantic controls; keep navigation and account state owners |
| Workspace header and column split | `WorkspaceMain.vue`, `ConversationPane.vue`, `WorkspaceMembersPanel.vue` | Keep current props/events; adjust layout and presentation |
| History and date boundary | `TextHistoryList.vue` | Preserve grouped rows, unread boundary, and scroll refs |
| Author, reply, mentions, deletion | `MessageItem.vue`, `MessageBody.vue` | Visual hierarchy only; preserve actions and disclosure rules |
| Attachment preview and download | `PublishedAttachmentCard.vue`, `ProtectedImageViewer.vue` | Style current authorized resources; no fixture media in production |
| Composer and reply context | `TextConversation.vue`, `TextMessageAttachmentPicker.vue`, `MentionPicker.vue` | Preserve send/retry/upload/mention controllers and keyboard contract |
| Active voice dock | `VoiceDock.vue` | Restyle current controls; do not create or destroy a media session from layout changes |

## Task 1: Canonical tokens and shared controls

**Files:**
- Modify: `clients/web/src/design/tokens.css`.
- Modify: `clients/web/src/design/foundation.css` only for shared button, field, focus, badge, and avatar rules.
- Test: `clients/web/src/design/design_v2_tokens.spec.ts`.

- [x] Add assertions for supplied canonical colors, focus handling, control sizes, and 280/248/64 layout values.
- [x] Run `npm test -- src/design/design_v2_tokens.spec.ts`; assertions failed against the old palette/header, then passed after token mapping.
- [x] Map canonical values to existing `--gc-*` names so current features keep their CSS contract; shared spacing/radius/layout tokens match the live HTML package.
- [x] Implement shared visual states through existing global classes, including focus-visible and reduced-motion handling; no permission visibility or button intent handler changed.
- [x] Run token and existing design-system contract tests.

## Task 2: Shell and R01/R02/R03 conversation presentation — complete

**Files:**
- Modify: `clients/web/src/design/shell.css`, `responsive_shell.css`, `navigation.css`, and `conversation.css` by extracting focused V2 leaf styles where a file would exceed the 120-line hard limit.
- Modify: `clients/web/src/style.css` to load the focused styles after existing CSS.
- Modify only where markup cannot express the reference with current real data: `WorkspaceApp.vue`, `WorkspaceSidebarTabs.vue`, `ConversationPane.vue`, `TextConversation.vue`, and `PublishedAttachmentCard.vue`.
- Test: `clients/web/src/design/design_v2_chat_geometry.spec.ts` and existing `chat_geometry.spec.ts` / `design_fidelity.spec.ts`.
- Visual evidence: `artifacts/design-v2/review.json` contains production Vue DOM bounds, expected live HTML bounds, and coordinate diffs. Per the user’s no-image direction, no screenshots or reference images were created or used.

- [x] Extend geometry tests for R01 1440×900, R02 390×844, and R03 1024×768. Existing nearest geometry test is `clients/web/src/conversation/chat_geometry.spec.ts`.
- [x] Run geometry tests and record expected token failures before CSS changes.
- [x] Implement shell columns, scroll regions, responsive drawer breakpoints, the 98 px desktop composer wrapper, the 70 px mobile composer wrapper, and 440×200 desktop / 144×144 mobile attachment preview limits.
- [x] Preserve authors, presence/member data sources, and server-backed channels/messages; no reference text or roster was added to product defaults.
- [x] Render actual Vue app components in Chromium at each canonical viewport. Compare element bounds with supplied live HTML and fix measured mismatches; all checked bounds have zero delta.
- [x] Run focused and full Web tests plus `npm run build`; save geometry diff in `artifacts/design-v2/review.json` without modifying references or using images.

## Stop condition

Stop the packet only when the real Web renders have been captured for all three states, required geometry matches the handoff, visual review has no unresolved high-impact mismatch, focused and native checks pass, and message/ACL/media lifecycle ownership is unchanged. Geometry review uses a test-only API fixture, and connected voice-dock layout uses its existing CSS class without starting a LiveKit session; this is recorded in the visual review report.

## Full package coverage

The live package supplies 30 HTML pages and `src/frames.json`. The actual `AGENT_START_HERE.md`, `SPEC.md`, and `GALLERY.html` names referenced by the older spec are absent from that updated package; use its `README.md`, the separately supplied implementation spec, the live pages, token JSON/CSS, and frame manifest as the available source of truth. Do not consume the package's embedded PNG/brand/scene pixels or use its synthetic `demo.js` behavior in product code.

| Handoff IDs | Real application components / existing route | Coverage after chat packet |
|---|---|---|
| R01–R03 | `WorkspaceApp`, `WorkspaceMain`, `ConversationPane`, `TextConversation`, history/message/attachment components | Desktop, mobile and tablet shell/chat bounds match; real Vue DOM compared |
| R04–R05, R27 | `ConversationPane`, `ScreenViewer`, voice room/participant components | Stage, controls, stream rail and participant grid match; no media session created |
| R06–R07, R21–R22 | `AdminPanel`, `AdminRolePermissions`, `AdminMembersSection` | Role table/footer and desktop/mobile member list implemented; R06, R07, R21, and R22 real Vue DOM geometry measured and matched |
| R08–R09, R24, R29 | `ChannelTopologyActions`, channel/category dialog, confirmation/context controls | Create dialogs and destructive confirmation match; permission filtering and API handlers preserved |
| R10–R11 | `AudioSettings`, audio device check and activation controls | Desktop/mobile audio settings layouts match; device/controller flows remain connected |
| R12 | `ProfileSettings` | Profile panel and save bar match |
| R13 | `WorkspaceSearchPanel` | Search panel matches without changing conversation/member data owners |
| R14, R18 | `WorkspaceApp` drawers, `WorkspaceMembersPanel`, `MemberPopover` | Mobile drawer and production member popover match |
| R15 | Existing shared controls distributed across production components | Reference-only catalog; canonical tokens/shared control styles validated against the real component system |
| R16–R17 | `AuthenticationLanding`, `PasswordResetCompletion` | Desktop/mobile auth card bounds match; registration remains open per the approved product brief |
| R19–R20, R30 | `ScreenViewer`, `ScreenReceiverDiagnosticsPanel`, `ScreenShareSetupDialog` | Mobile statistics panel and desktop/mobile quality dialogs match |
| R23 | `UpdateBanner`, `UpdateStatus` | Update banner matches and no longer shifts the app shell |
| R25 | `TextConversation`, `MentionPicker`, reply state in `MessageItem` | Reply strip, composer wrapper and input match in the real reply state |
| R26 | `PublishedAttachmentCard`, `ProtectedImageViewer` | Full-screen protected viewer matches; preview requests were blocked and no image pixels loaded |
| R28 | `DirectMessageNavigation`, `DirectMessageConversation` | DM history/composer dimensions match; current two-party access and send path retained |

## Completed implementation packets

1. **Tokens and shared controls:** mapped the canonical palette, spacing, type scale, focus and component aliases into the existing production CSS contract.
2. **Settings, auth, overlays and admin:** implemented the R06–R18, R21–R24 and R29 layouts using current data/API owners, ACL checks and mutation handlers.
3. **Media/service states:** aligned R04–R05, R19–R20, R23, R27 and R30 with production components. QA fixtures did not start LiveKit or claim hardware metrics.
4. **Conversation states:** aligned R25–R28 with production reply, attachment viewer and DM components. Image requests were blocked; the protected viewer was tested in its unavailable-preview state.
5. **All-frame verification:** `artifacts/design-v2/review.json` records every R01–R30 reference and DOM geometry delta. Raster images/screenshots were neither used nor produced, per the user's instruction.

**Scope controls:** The reference's simulated accounts/messages/stats are not product defaults. The component board is not a production route. The supplied HTML remains immutable. No screenshot, PNG, or other raster image may be generated or consumed for this task; actual/reference evidence is HTML-derived DOM geometry and computed style.

**UI/UX review carry-forward:** Keep the one-guild three-zone desktop structure; leave the idle mobile voice dock hidden while exposing it during active, connecting, reconnecting, and error states; keep touch targets at least 44 px; use labels, inline errors, semantic danger actions, and explicit overlay close/focus return; preserve separate voice/stream audio and do not resize or discard drafts to make the layout denser. The review's R16/R17 screenshot says registration is closed, but the approved product brief requires free registration, so the existing working registration flow remains available while its card layout follows the handoff geometry. Review advice is implementation context; it cannot override the product brief or ACL/media invariants.

**Full-goal stop condition:** All R01–R30 states have explicit production component mappings and DOM review records. `R15` is a reference-only component catalog and is covered through the production token/shared-control tests rather than a new product route. Geometry differences for the measurable production states are zero after the final pass. Real device/browser engine/live-media behavior remains outside the fixture-only visual check; the existing behavior tests and controllers remain the validation for those lifecycles.
