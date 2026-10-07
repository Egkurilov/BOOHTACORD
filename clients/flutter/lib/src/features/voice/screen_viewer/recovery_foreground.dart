import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';
import 'recovery.dart';

extension VoiceScreenViewerForeground on VoiceController {
  void setRemoteScreenViewerForeground(bool foreground) {
    if (remoteScreenViewerForeground == foreground) return;
    remoteScreenViewerForeground = foreground;
    if (!foreground) {
      remoteScreenViewerRecoveryDeadline.pause();
      remoteScreenViewerRecoveryTimer?.cancel();
      remoteScreenViewerRecoveryTimer = null;
      return;
    }
    final publication = remoteScreenViewerRecoveryPublication;
    final isCurrent = remoteScreenViewerRecoveryIsCurrent;
    if (publication == null || isCurrent == null) return;
    scheduleRemoteScreenViewerRecovery(this, publication, isCurrent);
  }
}
