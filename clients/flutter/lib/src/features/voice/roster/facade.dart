import 'package:http/http.dart' as http;

import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin VoiceRosterFacade on ApiFacadeBase {
  late final _voiceRoster = VoiceRosterApi(transport);

  Future<List<VoiceRoomRoster>> voiceParticipants() =>
      _voiceRoster.voiceParticipants();

  Future<http.StreamedResponse> voiceRosterEvents() =>
      _voiceRoster.voiceRosterEvents();
}
