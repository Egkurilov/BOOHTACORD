import '../../models.dart';
import '../../features/voice/roster_state/controller.dart';
import '../composition/owners.dart';

mixin AppVoiceRosterAccess on AppOwners {
  List<VoiceRoomRoster>? get voiceRosters => voiceRoster.voiceRosters;

  set voiceRosters(List<VoiceRoomRoster>? value) =>
      voiceRoster.voiceRosters = value;

  String? get voiceRosterError => voiceRoster.voiceRosterError;

  set voiceRosterError(String? value) => voiceRoster.voiceRosterError = value;

  Future<void> refreshVoiceRosters() => voiceRoster.refreshVoiceRosters();
}
