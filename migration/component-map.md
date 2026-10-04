# BOOHTACORD Design V2: component map

Baseline: `560a3972` (2026-10-04). Target: the existing Vue application in
`clients/web/src`; `clients/web/package-lock.json` pins its native checks.
The supplied implementation spec defines proposed component names, not a
requirement to create duplicate screen trees. The live HTML is a visual
reference; product state and actions remain in the modules below.

| V2 role / reference | Existing presentation owner | Preserved state or action owner | Nearest check |
| --- | --- | --- | --- |
| Tokens, type, common controls (R15) | `design/tokens.css`, `design/design_v2_foundation.css`, native controls in each leaf | Native form state and server validation remain in their leaves | `design/design_v2_tokens.spec.ts`, `design/contrast_contract.spec.ts` |
| AppShell, three columns, mobile drawers (R01–R03, R14) | `workspace/WorkspaceApp.vue`, `WorkspaceMain.vue`, `WorkspaceSidebarTabs.vue`, `design/design_v2_mobile_navigation.css` | `workspace/workspace_navigation.ts`, `useWorkspaceDrawers.ts`, `channel/topology_store.ts`, `authorization/permission_store.ts` | `design/shell_reference_geometry.spec.ts`, `design/mobile_navigation_v2.spec.ts`, browser R01–R03 captures |
| Guild navigation, channel/category rows | `channel/ChannelNavigation.vue`, `channel/member_topology/ChannelTopologyActions.vue`, `direct_message/DirectMessageNavigation.vue` | `channel/topology_store.ts`, `channel/voice_navigation_presence.ts`, `direct_message/direct_message_store.ts` | `channel/topology_store.spec.ts`, `design/design_v2_coverage.spec.ts` |
| Account footer and voice dock | `workspace/WorkspaceUserFooter.vue`, `voice/VoiceDock.vue` | `workspace/voice_controls.ts`, `voice/connection_store.ts`, `voice/activation_store.ts` | `voice/voice_dock_transition_states.spec.ts`, `workspace/voice_controls.spec.ts` |
| ConversationPane and header (R01–R03) | `conversation/ConversationPane.vue`, `conversation/TextConversation.vue`, `shared/workspace_header/WorkspaceHeaderActions.vue` | `conversation/message_store.ts`, `workspace/workspace_navigation.ts`, `authorization/permission_store.ts` | `design/design_v2_chat_geometry.spec.ts`, R01–R03 browser captures |
| MessageList and MessageRow | `conversation/TextHistoryList.vue`, `conversation/MessageItem.vue`, `direct_message/DirectMessageHistoryList.vue` | `conversation/message_store.ts`, `message_grouping.ts`, `use_visible_read.ts`; DM store/read gate | `conversation/message_grouping_presentation.spec.ts`, `conversation/message_store.spec.ts` |
| Composer, reply, mentions, emoji (R25, R28) | `conversation/TextConversation.vue`, `conversation/MentionAutocomplete.vue`, `conversation/EmojiPicker.vue`, `direct_message/DirectMessageConversation.vue` | `conversation/use_scoped_send.ts`, `use_saved_composer.ts`, attachment queues, `direct_message/direct_message_store.ts` | `conversation/use_scoped_send.spec.ts`, `conversation/emoji_picker.spec.ts`, `direct_message/direct_message_store.spec.ts` |
| Message attachment and protected viewer (R26) | `conversation/PublishedAttachmentCard.vue`, `ProtectedImageViewer.vue`, TEXT/DM attachment pickers | `conversation/text_attachment_upload_client.ts`, protected preview URL, DM attachment client | `conversation/published_attachment_card.spec.ts`, `conversation/protected_image_viewer.spec.ts` |
| Members panel, member sheet (R18) | `workspace/WorkspaceMembersPanel.vue`, `MemberPopover.vue` | `identity/author_directory.ts`, `identity/guild_presence.ts`, `workspace/workspace_navigation.ts`; server member/DM actions | `design/member_popover_v2.spec.ts`, mobile member browser probe |
| Voice room and participant cards (R04–R05, R27) | `voice/VoicePrejoin.vue`, `VoiceRoomConnected.vue`, `VoiceParticipantVolumes.vue`, `VoiceDock.vue` | `voice/connection_store.ts`, `voice/voice_session.ts`, LiveKit gateway and server admission | `voice/voice_room_v2_layout.spec.ts`, `voice/connection_store.spec.ts` |
| Media stage, rail, stats, quality (R19–R20, R30) | `voice/ScreenViewer.vue`, `ScreenViewerRail.vue`, `ScreenReceiverDiagnosticsPanel.vue`, `ScreenShareSetupDialog.vue` | `voice/screen_viewer_controller.ts`, `use_screen_receiver_diagnostics.ts`, `screen_profile/*`, LiveKit track attachment | `voice/screen_viewer_reference.spec.ts`, `voice/screen_receiver_diagnostics.spec.ts` |
| Profile and audio settings (R10–R12) | `identity/ProfileSettings.vue`, `voice/AudioSettings.vue`, `voice/AudioDeviceCheck.vue` | `identity/profile_client.ts`, `voice/audio_settings_store.ts`, browser device APIs | `identity/profile_settings_v2_layout.spec.ts`, `voice/audio_settings_v2_layout.spec.ts` |
| Admin roles, members, channel inspector (R06–R09, R21–R22, R24, R29) | `admin/panel/AdminPanel.vue`, `admin/role_permissions/AdminRolePermissions.vue`, `admin/members/AdminMembersSection.vue`, `channel/AdminTopologyControls.vue` | `authorization/permission_store.ts`, `admin/role_permissions/role_policy_editor.ts`, topology/member API clients | `admin/role_permissions/role_permissions_v2_layout.spec.ts`, `design/admin_members_v2.spec.ts` |
| Search, auth, update (R13, R16–R17, R23) | `search/SearchPanel.vue`, `identity/AuthenticationLanding.vue`, `identity/PasswordResetCompletion.vue`, workspace update banner | `search/search_context_controller.ts`, `identity/auth_client.ts`, `updates/update_store.ts` | `design/search_panel_contract.spec.ts`, `design/authentication_v2.spec.ts` |

The Web presentation above covers R01–R30. `DESIGN_V2_CURRENT_PIXEL_REVIEW.md`
and `DESIGN_V2_FULL_AUDIT.md` in the visual artifact directory record actual
screens, diffs, missing goldens and unresolved product/reference conflicts.
No row here claims a pixel-perfect release gate.

## Flutter adaptation (separate render engine)

| V2 role | Existing Flutter presentation | Preserved owner / check |
| --- | --- | --- |
| Tokens and common controls | `lib/src/theme.dart`, native Material controls | `test/theme_tokens_test.dart` |
| R01–R03 shell, messages, composer, DM | `lib/src/screens/workspace_screen.dart` (`_Sidebar`, `_Conversation`, `_MessageRow`, `_DirectConversation`) | `lib/src/features/workspace/*`, conversation features; `test/workspace_screen_test.dart`, `test/message_presentation_test.dart` |
| R04–R05, R19–R20, R27, R30 voice and viewer | `workspace_screen.dart`, `voice_viewer_layout.dart`, `voice_screen_stage.dart`, `voice_screen_selection_rail.dart`, `screen_receiver_diagnostics.dart` | voice/media feature controllers; `test/voice_screen_stage_test.dart`, `test/voice_screen_selection_rail_test.dart` |
| R06–R14, R18, R21–R24, R29 admin/settings/nav | `admin_screen.dart`, `profile_screen.dart`, `workspace_screen.dart` member/audio/search panels | admin/workspace features and API; `test/admin_topology_widget_test.dart`, `test/workspace_screen_test.dart` |
| R16–R17, R26 auth and attachments | `auth_screen.dart`, `password_reset_screen.dart`, `widgets/message_attachment_list.dart` | session/attachment features; `test/auth_screen_test.dart`, `test/message_attachment_list_test.dart` |

Flutter has its own visual acceptance in
`docs/superpowers/plans/2026-10-03-design-v2-flutter.md` and `backlog/tasks.yaml`
(`FV2-*`). Chromium PNG files are composition references, not strict Flutter
goldens. Remaining Flutter leaves and device checks stay open.
