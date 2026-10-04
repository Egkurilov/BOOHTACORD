import 'dart:async';

import '../../../services/voice_lease_revocation.dart';
import '../lifecycle/controller.dart';

extension VoiceLeaseEventsRevocation on VoiceController {
  void dispatchVoiceRevocation(Map<String, dynamic> payload) {
    if (disposed || !scope.capture().isActive) return;
    final revocation = VoiceLeaseRevocation.parse(
      payload['lease_id'],
      payload['reason'],
      activeLeaseId: leaseId ?? disconnect.leaseId,
      admissionPending: voiceAdmissionPending,
    );
    if (revocation == null) return;
    if (leaseId == revocation.leaseId) disconnect.bind(revocation.leaseId, voiceChannel?.id ?? disconnect.channelId ?? '');
    final accepted = disconnect.server(revocation.leaseId, revocation.reason);
    if (accepted && room == null && !voiceAdmissionPending) { showVoiceDisconnect(); return; }
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
    disconnect.bind(leaseId, voiceChannel?.id ?? disconnect.channelId ?? '');
    disconnect.server(leaseId, reason);
    final generation = disconnect.generation;
    final ticket = scope.capture();
    final closing = leaveVoice(explicit: false);
    final revision = operationRevision;
    await closing;
    if (!active(ticket, revision) || generation != disconnect.generation) return;
    showVoiceDisconnect();
  }
}
