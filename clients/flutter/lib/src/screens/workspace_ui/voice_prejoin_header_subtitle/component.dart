import '../native_bindings.dart';
import '../../../features/voice/roster_state/phase.dart';

String workspaceVoicePrejoinHeaderSubtitle(
  AppState state,
  GuildChannel channel,
) {
  final roster = state.voiceRosters
      ?.where((item) => item.channelId == channel.id)
      .firstOrNull;
  if (state.voiceRoster.phase == VoiceRosterPhase.sessionExpired) {
    return 'Голосовой канал · сессия завершена';
  }
  if (state.voiceRoster.phase == VoiceRosterPhase.stale && roster != null) {
    return 'Голосовой канал · состав устарел';
  }
  if (state.voiceRosterError != null) {
    return 'Голосовой канал · состав недоступен';
  }
  if (roster == null) return 'Голосовой канал · проверяем состав';
  if (roster.participants.isEmpty) return 'Голосовой канал · пока пусто';
  return 'Голосовой канал · сейчас: ${roster.participants.length}';
}
