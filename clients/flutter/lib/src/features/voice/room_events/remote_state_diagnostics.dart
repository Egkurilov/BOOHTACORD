import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../services/screen_share_diagnostics.dart';

void logRemoteVoiceState(Room room, ScreenShareDiagnosticEvent event) {
  final counts = screenShareRemoteCounts(room);
  logScreenShareDiagnostic(
    event,
    platform: defaultTargetPlatform,
    remoteParticipants: counts?.participants,
    remoteScreenPublications: counts?.publications,
  );
}
