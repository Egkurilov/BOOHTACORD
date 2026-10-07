import 'package:livekit_client/livekit_client.dart';

import '../lifecycle/controller.dart';

void refreshRemoteVoiceNavigation(
  VoiceController voice,
  Room room,
  bool Function() owns,
) {
  if (!owns() || !identical(voice.room, room)) return;
  voice.observeVoiceStreamStarts(room);
  voice.notifyListeners();
}
