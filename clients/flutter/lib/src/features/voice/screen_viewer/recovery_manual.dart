import '../lifecycle/controller.dart';
import 'subscription_recovery.dart';

extension VoiceScreenViewerManualRecovery on VoiceController {
  void retryRemoteScreenViewerRecovery() {
    if (!remoteScreenViewerForeground ||
        remoteScreenViewerRecoveryAttempt < 2) {
      return;
    }
    final publication = remoteScreenViewerRecoveryPublication;
    final isCurrent = remoteScreenViewerRecoveryIsCurrent;
    if (publication == null || isCurrent == null || !isCurrent()) return;
    retryRemoteScreenViewerSubscription(
      this,
      publication,
      isCurrent,
      manual: true,
    );
  }
}
