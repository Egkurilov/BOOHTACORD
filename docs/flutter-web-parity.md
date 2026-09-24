# Flutter ↔ web parity checklist

The Vue client is the behavioral and visual reference. Flutter must reuse the same REST, realtime, ACL and LiveKit contracts; it must not replace missing behavior with decorative controls.

| Area | Web reference | Flutter status |
| --- | --- | --- |
| Authentication and maintenance | `AuthenticationLanding`, `MaintenanceBanner` | Partial: login/register; maintenance missing |
| Shell and responsive drawers | `WorkspaceApp`, `WorkspaceMain`, `useWorkspaceDrawers` | Partial |
| Profile and avatar | `ProfileSettings`, `WorkspaceUserFooter` | Missing |
| Channels and topology | `ChannelNavigation`, `AdminTopologyControls` | Member navigation present; admin controls missing |
| Text chat | `TextConversation`, `MessageItem` | Basic history/send only |
| Replies, edit and delete | `MessageItem`, `message_store` | Missing |
| Attachments and preview | `TextMessageAttachmentPicker`, `TextMessageAttachments` | Missing |
| Channel and global search | `TextMessageSearch`, `WorkspaceSearchPanel` | Missing |
| Direct messages | `DirectMessageConversation`, `DirectMessageNavigation` | Basic history/send/unread present; actions/search/replies missing |
| Members and member popover | `WorkspaceMembersPanel`, `MemberPopover` | Directory/presence present; popover/DM/volume missing |
| Voice lifecycle | `VoiceDock`, `connection_store` | Join/transfer/mute/deafen present |
| Voice reconnect and permissions | `connection_lifecycle`, `bounded_voice_reconnect_policy` | Partial |
| Audio devices, processing and PTT | `AudioSettings`, `activation_store` | Missing |
| Participant state and volume | `VoiceParticipantStrip`, `VoiceParticipantVolumes` | Partial |
| Screen publication and diagnostics | `ScreenViewer`, `ScreenDiagnosticsPanel` | Viewer partial; publication/diagnostics missing |
| Administration and audit | `AdminPanel`, `AdminMembersSection`, `AdminAuditSection` | Missing |

Implementation order: shell/profile → message parity → search/attachments → audio and screen controls → administration → screenshot and physical-device evidence.
