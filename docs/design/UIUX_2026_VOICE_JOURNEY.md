# Voice and screen-share UX journey (#300)

Date: 2026-10-10  
Status: presentation journey documented; platform runtime acceptance remains `NOT_RUN`.

This flow maps the existing Web and Flutter voice/media lifecycle for issue [#300](https://github.com/Egkurilov/BOOHTACORD/issues/300). It does not change LiveKit, OS permission, screen-capture, or server contracts. The browser/OS owns its native microphone and screen picker prompts; the app reports the current join or publication state around those prompts.

| Phase | User-facing state and next action | Web | Flutter |
| --- | --- | --- | --- |
| Idle / choose join mode | “Вы не подключены”; choose voice with microphone or listener mode. | `VoicePrejoin.vue` shows primary “Подключиться к голосу” and secondary “Подключиться без микрофона”. | `VoicePrejoinCard` exposes the same two join modes. |
| Permission request / connecting | After choosing voice with microphone, the native permission prompt may appear during join. The app announces “Подключаемся к голосовой комнате”; repeated join actions are disabled. | `VoiceConnectionState.JOINING`; the browser controls its permission prompt. | `VoicePhase.joining`; the native platform controls its permission prompt. |
| Permission denied | The user remains connected as a listener, sees why the microphone is unavailable, and can retry after changing site/device permission. | A denied capture maps to `LISTENER_PERMISSION_DENIED`; `VoiceDock` announces listener fallback, labels the retry, and a single click retries publication. `NotFoundError` and `OverconstrainedError` produce device-specific join guidance while the listener CTA stays available. | `VoiceMicrophoneUnavailableNotice` explains listener fallback and offers retry; PTT mode keeps its existing key/touch action. |
| Joined / active | The voice dock confirms the active room; participant controls and roster remain available. A listener is not presented as publishing microphone audio. | `VoiceDock` announces the connected state; `VoiceParticipantStatus` distinguishes unavailable, muted, speaking and deafened states. | `VoiceConnectionBadge`, participant cards and the voice dock expose connected/listener and local mic states. |
| Screen setup / source selection | From the connected room, choose “Показать экран”, review the recommended profile, then continue to the platform picker. Cancel returns to the connected room without publishing a track. | `ScreenShareSetupDialog` explains the OS picker and profile; source selection remains in the native browser picker. | `ScreenShareSetupDialog` presents the source inventory and profile before native capture starts. |
| Publishing / live | Starting and active publication are separate. The user can stop the share; advanced diagnostics remain behind disclosure. | `ScreenShareState.STARTING` disables duplicate starts; `SHARING` exposes stop and advanced diagnostics. | `ScreenSharePhase.starting` blocks repeat starts; `sharing` exposes stop and disclosure-controlled diagnostics. |
| Recovering | Voice reconnection is explicit and distinct from a disconnected or ended screen share. The user can keep voice controls available while recovery proceeds. | `VoiceDock` and `VoiceRoomConnected` announce reconnecting; bounded retry policy is unchanged. | `VoiceConnectionBadge` announces reconnecting; voice reconnect policy is unchanged. |
| Ended / error | Picker cancellation, permission denial, unavailable sources, connection errors and ended publication are reported separately. The user gets a next action when retry is valid. | `screenFailureMessage` distinguishes `AbortError`, `NotAllowedError` and `NotReadableError`; voice prejoin exposes join failures and revocation notices. | Setup cancellation preserves the voice room; permission/capability errors remain explicit; an ended stream offers another source or return to participants. |

## Regression map

- Web prejoin choice, joining progress, microphone-denial notice and 320×640/200% text layout: `clients/web/tests/accessibility/accessibility.browser.spec.ts`.
- Web listener retry behavior and accessible dock copy: `clients/web/src/voice/microphone_controls.spec.ts`, `clients/web/src/voice/voice_dock_reconnect_copy.spec.ts`, and `clients/web/src/voice/connection_state/join_error.spec.ts`.
- Web connection and revocation states: `clients/web/src/voice/voice_dock_transition_states.spec.ts` and `clients/web/src/voice/disconnect_notice/presentation.spec.ts`.
- Web screen cancellation, permission denial and unavailable-source copy: `clients/web/src/voice/screen_feedback.spec.ts`, `clients/web/src/voice/screen_capture_support.spec.ts`, and `clients/web/src/voice/screen_publisher/adapter.spec.ts`.
- Flutter connection, listener retry/PTT and ended-share behavior: `clients/flutter/test/voice_connection_badge_test.dart`, `clients/flutter/test/voice_microphone_unavailable_notice_test.dart`, `clients/flutter/test/screen_setup/cancellation_test.dart`, `clients/flutter/test/screen_setup/capabilities_test.dart`, and `clients/flutter/test/voice_screen_ended_test.dart`.

## Acceptance boundary

Automated component/widget tests establish copy, state transitions and responsive geometry. They do not prove that each browser or OS presents its real permission/picker prompt as expected, that publishing survives a native restart, or that LiveKit recovers after an actual SFU outage. Android/iOS/macOS/Windows media runtime and physical viewport acceptance, plus the owned real-SFU stop/restart/rejoin flow, remain `NOT_RUN` and keep #300 open.
