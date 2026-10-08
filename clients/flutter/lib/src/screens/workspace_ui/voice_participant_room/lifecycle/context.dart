import '../../native_bindings.dart';

abstract class WorkspaceVoiceParticipantRoomContext extends StatelessWidget {
  const WorkspaceVoiceParticipantRoomContext({
    super.key,
    required this.state,
    required this.room,
    required this.participants,
    required this.screens,
    required this.onScreenSelected,
  });
  final AppState state;
  final Room? room;
  final List<RemoteParticipant> participants;
  final List<RemoteParticipant> screens;
  final ValueChanged<String?> onScreenSelected;
}
