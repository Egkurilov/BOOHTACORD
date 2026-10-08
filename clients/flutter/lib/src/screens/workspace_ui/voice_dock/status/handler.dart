import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceVoiceDockWorkspaceStatusBinding on WorkspaceVoiceDockContext {
  @override
  String get workspaceStatus {
    return executeWorkspaceVoiceDockWorkspaceStatus();
  }
}

extension WorkspaceVoiceDockWorkspaceStatusAction on WorkspaceVoiceDockContext {
  String executeWorkspaceVoiceDockWorkspaceStatus() =>
      switch (state.voicePhase) {
        VoicePhase.joining => 'Подключаемся к голосовому каналу',
        VoicePhase.reconnecting => 'Восстанавливаем голосовое соединение',
        VoicePhase.leaving => 'Завершаем голосовое подключение',
        VoicePhase.connected || VoicePhase.listener => 'Голос подключён',
        _ => 'В голосовом канале',
      };
}
