import 'dart:async';

import '../../../services/voice_lease_revocation.dart';
import '../lifecycle/controller.dart';

extension VoiceLeaseEventsRevocation on VoiceController {
  void dispatchVoiceRevocation(Map<String, dynamic> payload) {
    if (disposed || !scope.capture().isActive) return;
    final revocation = VoiceLeaseRevocation.parse(
      payload['lease_id'],
      payload['reason'],
      activeLeaseId: leaseId,
      admissionPending: voiceAdmissionPending,
    );
    if (revocation == null) return;
    if (voiceAdmissionPending) {
      revokedVoiceLeasesDuringJoin[revocation.leaseId] = revocation.reason;
      if (revokedVoiceLeasesDuringJoin.length > 16) {
        revokedVoiceLeasesDuringJoin.remove(
          revokedVoiceLeasesDuringJoin.keys.first,
        );
      }
      if (leaseId == revocation.leaseId) {
        unawaited(pendingRoom?.disconnect().catchError((Object _) {}));
      }
    } else {
      unawaited(handleVoiceLeaseRevoked(revocation.leaseId, revocation.reason));
    }
  }

  Future<void> handleVoiceLeaseRevoked(String leaseId, String reason) async {
    if (this.leaseId != leaseId || room == null) return;
    final ticket = scope.capture();
    final closing = leaveVoice();
    final revision = operationRevision;
    await closing;
    if (!active(ticket, revision)) return;
    voicePhase = VoicePhase.error;
    error = VoiceLeaseRevocation(leaseId: leaseId, reason: reason).message;
    notifyListeners();
  }
}
