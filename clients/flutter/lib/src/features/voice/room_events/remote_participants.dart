import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../../../services/screen_share_diagnostics.dart';
import '../lifecycle/controller.dart';
import 'refresh_voice_navigation.dart';
import 'remote_state_diagnostics.dart';

extension VoiceEventsRemoteParticipants on VoiceController {
  void bindRemoteParticipantEvents(
    Room room,
    EventsListener<RoomEvent> listener,
    bool Function() owns,
  ) {
    listener.on<ParticipantConnectedEvent>((_) {
      logRemoteVoiceState(room, ScreenShareDiagnosticEvent.remoteParticipantConnected);
      refreshRemoteVoiceNavigation(this, room, owns);
    });
    listener.on<ParticipantDisconnectedEvent>((event) {
      if (!owns()) return;
      logRemoteVoiceState(room, ScreenShareDiagnosticEvent.remoteParticipantDisconnected);
      final replacement = room.remoteParticipants[event.participant.identity];
      if (replacement == null || identical(replacement, event.participant)) {
        removeRemoteScreenThumbnail(event.participant.identity);
      }
      if (selectedRemoteScreenViewerIdentity == event.participant.identity) {
        selectedRemoteScreenViewerIdentity = null;
      }
      refreshRemoteVoiceNavigation(this, room, owns);
    });
    listener.on<ActiveSpeakersChangedEvent>(
      (_) => refreshRemoteVoiceNavigation(this, room, owns),
    );
  }
}
