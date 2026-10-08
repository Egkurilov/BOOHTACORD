import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceVoiceDockWorkspaceSubtitleBinding on WorkspaceVoiceDockContext {
  @override
  String get workspaceSubtitle {
    return executeWorkspaceVoiceDockWorkspaceSubtitle();
  }
}

extension WorkspaceVoiceDockWorkspaceSubtitleAction
    on WorkspaceVoiceDockContext {
  String executeWorkspaceVoiceDockWorkspaceSubtitle() {
    final channel = state.voiceChannel!;
    final room = state.room;
    if (!workspaceConnected || room == null) return channel.name;
    final count = room.remoteParticipants.length + 1;
    final lastTwoDigits = count % 100;
    final lastDigit = count % 10;
    final noun = lastTwoDigits >= 11 && lastTwoDigits <= 14
        ? 'участников'
        : switch (lastDigit) {
            1 => 'участник',
            2 || 3 || 4 => 'участника',
            _ => 'участников',
          };
    return '${channel.name} · $count $noun';
  }
}
