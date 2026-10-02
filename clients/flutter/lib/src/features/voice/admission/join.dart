import 'package:livekit_client/livekit_client.dart';

import '../../../models.dart';
import '../../../services/android_audio_devices.dart';
import '../../../services/screen_thumbnail.dart';
import '../../../services/voice_lease_revocation.dart';
import '../lifecycle/controller.dart';
import 'prepare.dart';
import 'enable.dart';

extension VoiceAdmissionJoin on VoiceController {
  Future<void> joinVoice(
    GuildChannel channel, {
    bool listenerOnly = false,
  }) async {
    final ticket = scope.capture();
    final admitted = operationRevision;
    await closing;
    if (!active(ticket, admitted) ||
        channel.admissionClosed ||
        voiceAdmissionPending) {
      return;
    }
    if (voiceChannel?.id == channel.id && room != null) return;
    final revision = ++operationRevision;
    screenThumbnails.clear();
    closeScreenPreviewSubscriptions();
    screenPreviewSubscriptionQueue = ScreenPreviewSubscriptionQueue();
    selectedRemoteScreenViewerIdentity = null;
    voicePhase = VoicePhase.joining;
    voicePingMs = null;
    voiceAdmissionPending = true;
    microphoneUnavailable = false;
    error = null;
    notifyListeners();
    Room? candidate;
    EventsListener<RoomEvent>? events;
    String? admittedLease;
    var connected = false;
    try {
      final result = await api.voiceCredential(channel.id, transfer: true);
      admittedLease = result.$1;
      checkAdmission(ticket, revision, admittedLease);
      leaseId = admittedLease;
      await loadVoiceVolumes(ticket, revision, admittedLease);
      checkAdmission(ticket, revision, admittedLease);
      candidate = createRoom(voiceRoomOptions());
      pendingRoom = candidate;
      bindVoiceRoomEvents(candidate);
      events = voiceEvents;
      await candidate.connect(
        result.$2.url,
        result.$2.token,
        connectOptions: const ConnectOptions(autoSubscribe: false),
      );
      checkAdmission(ticket, revision, admittedLease);
      await selectVoiceOutput();
      checkAdmission(ticket, revision, admittedLease);
      room = candidate;
      voiceChannel = channel;
      subscribeCurrentRemoteVoiceTracks(candidate);
      await applySavedVoiceVolumes(candidate);
      checkAdmission(ticket, revision, admittedLease);
      await enableVoiceMicrophone(candidate, listenerOnly, ticket, revision);
      checkAdmission(ticket, revision, admittedLease);
      startVoiceConnectionStatsPolling(candidate);
      observeVoiceStreamStarts(candidate);
      connected = true;
    } catch (cause) {
      if (active(ticket, revision)) {
        stopVoiceConnectionStatsPolling();
        final revoked = revokedVoiceLeasesDuringJoin.remove(admittedLease);
        error = revoked != null
            ? VoiceLeaseRevocation(
                leaseId: admittedLease!,
                reason: revoked,
              ).message
            : cause is VoiceLeaseRevocation
            ? cause.message
            : formatError(cause);
        voicePhase = VoicePhase.error;
        room = null;
        leaseId = null;
        voiceChannel = null;
        mutedScreenShareAudioIdentities.clear();
        try {
          await AndroidAudioDevices.clearNativeOutput();
        } catch (_) {}
      }
    } finally {
      if (!connected) {
        try {
          await candidate?.disconnect();
        } catch (_) {}
        await events?.dispose();
        if (identical(voiceEvents, events)) voiceEvents = null;
        if (admittedLease != null && ticket.isActive) {
          try {
            await api.releaseVoice(admittedLease);
          } catch (_) {}
        }
      }
      if (identical(pendingRoom, candidate)) pendingRoom = null;
      if (active(ticket, revision)) {
        voiceAdmissionPending = false;
        notifyListeners();
      }
    }
  }
}
