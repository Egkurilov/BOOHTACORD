import 'controller.dart';

extension VoiceRosterRefresh on VoiceRosterController {
  Future<void> refreshVoiceRosters() async {
    final ticket = scope.capture();
    if (disposed || !ticket.isActive) return;
    if (!isReady() || !hasUser() || loading) return;
    loading = true;
    final expected = ++revision;
    try {
      final rosters = await api.voiceParticipants();
      if (!ticket.isActive || expected != revision || !isReady()) return;
      voiceRosters = rosters;
      voiceRosterError = null;
    } catch (cause) {
      if (!ticket.isActive || expected != revision || !isReady()) return;
      voiceRosters = null;
      voiceRosterError = message(cause);
    } finally {
      if (ticket.isActive && expected == revision) {
        loading = false;
        changed();
      }
    }
  }
}
