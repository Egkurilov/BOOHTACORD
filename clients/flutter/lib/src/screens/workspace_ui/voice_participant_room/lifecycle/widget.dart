import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceVoiceParticipantRoom extends WorkspaceVoiceParticipantRoomContext
    with WorkspaceVoiceParticipantRoomBuildBinding {
  const WorkspaceVoiceParticipantRoom({
    super.key,
    required super.state,
    required super.room,
    required super.participants,
    required super.screens,
    required super.onScreenSelected,
  });
}
