import 'package:livekit_client/livekit_client.dart';

import '../../../models.dart';
import '../../../services/screen_thumbnail.dart';
import '../lifecycle/controller.dart';
import 'prepare.dart';
import 'enable.dart';
import 'failure.dart';

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
    disconnect.selectChannel(channel.id);
    if (disconnect.notice?.reconnectAllowed == false) return;
    disconnect.reset(); revokedVoiceLeasesDuringJoin.clear();
    disconnect.channelId = channel.id;
    final disconnectGeneration = disconnect.generation;
    final revision = ++operationRevision;
    screenThumbnails.clear();
    closeScreenPreviewSubscriptions();
    screenPreviewSubscriptionQueue = ScreenPreviewSubscriptionQueue();
    selectedRemoteScreenViewerIdentity = null;
    transientScreenShareVolumes.clear();
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
    void checkCurrentAdmission(String lease) {
      if (disconnect.generation != disconnectGeneration) throw CancelledVoiceAdmission();
      checkAdmission(ticket, revision, lease);
    }
    try {
      final result = await api.voiceCredential(channel.id, transfer: true);
      admittedLease = result.$1;
      if (!active(ticket, revision) || disconnect.generation != disconnectGeneration) throw CancelledVoiceAdmission();
      disconnect.bind(admittedLease, channel.id);
      checkCurrentAdmission(admittedLease);
      leaseId = admittedLease;
      await loadVoiceVolumes(ticket, revision, admittedLease);
      checkCurrentAdmission(admittedLease);
      candidate = createRoom(voiceRoomOptions());
      pendingRoom = candidate;
      bindVoiceRoomEvents(candidate);
      events = voiceEvents;
      await candidate.connect(
        result.$2.url,
        result.$2.token,
        connectOptions: const ConnectOptions(autoSubscribe: false),
      );
      checkCurrentAdmission(admittedLease);
      await selectVoiceOutput();
      checkCurrentAdmission(admittedLease);
      room = candidate;
      voiceChannel = channel;
      subscribeCurrentRemoteVoiceTracks(candidate);
      await applySavedVoiceVolumes(candidate);
      checkCurrentAdmission(admittedLease);
      await enableVoiceMicrophone(candidate, listenerOnly, ticket, revision);
      checkCurrentAdmission(admittedLease);
      startVoiceConnectionStatsPolling(candidate);
      observeVoiceStreamStarts(candidate);
      connected = true;
    } catch (cause) {
      if (active(ticket, revision)) {
        await failVoiceAdmission(cause, admittedLease, presentCause: disconnect.generation == disconnectGeneration);
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
