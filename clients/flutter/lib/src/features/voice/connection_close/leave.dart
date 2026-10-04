import 'dart:async';
import '../../../services/android_audio_devices.dart';
import '../../screen/lifecycle/controller.dart';
import '../lifecycle/controller.dart';

extension VoiceConnectionCloseLeave on VoiceController {
  Future<void> leaveVoice({bool explicit = true}) {
    if (explicit && (room != null || voiceAdmissionPending || disconnect.notice != null)) { disconnect.local(); error = null; }
    final previous = closing;
    if (previous != null) return previous;
    if (leaseId != null) disconnect.bind(leaseId!, voiceChannel?.id ?? disconnect.channelId ?? '');
    final operation = closeVoice(++operationRevision);
    closing = operation;
    return operation.whenComplete(() {
      if (identical(closing, operation)) closing = null;
    });
  }

  Future<void> closeVoice(int revision) async {
    unawaited(flushVoiceVolumes());
    final ticket = scope.capture();
    final connected = room;
    final pending = pendingRoom;
    final lease = leaseId;
    audio.nativeNoise.cancel();
    audio.nativeMicrophone.pause();
    audio.microphoneMutedIntent = true;
    final stopScreen = screen.stopScreenShare();
    room = null;
    pendingRoom = null;
    leaseId = null;
    voiceAdmissionPending = false;
    stopVoiceConnectionStatsPolling();
    voicePhase = VoicePhase.leaving;
    clearVoiceStreamNotice(resetTracker: true, notify: false);
    pushToTalkPressed = false;
    notifyListeners();
    await stopScreen;
    for (final target in {connected, pending}) {
      try {
        await target?.disconnect();
      } catch (_) {}
    }
    try {
      await AndroidAudioDevices.clearNativeOutput();
    } catch (_) {}
    await audio.nativeMicrophone.clear();
    await disposeVoiceEvents();
    if (lease != null && ticket.isCurrent) {
      try {
        await api.releaseVoice(lease);
      } catch (cause) {
        if (ticket.isCurrent && revision == operationRevision) {
          error = formatError(cause);
        }
      }
    }
    if (!ticket.isCurrent || revision != operationRevision || disposed) return;
    voicePingMs = null;
    voiceChannel = null;
    mutedScreenShareAudioIdentities.clear();
    transientScreenShareVolumes.clear();
    microphoneMuted = false;
    microphoneUnavailable = false;
    deafened = false;
    deafenChanging = false;
    listenerOnly = false;
    mutedBeforeDeafen = false;
    microphoneMutedBeforePtt = false;
    voicePhase = disconnect.notice != null && disconnect.notice!.source != 'local' ? VoicePhase.error : VoicePhase.idle;
    notifyListeners();
  }

  Future<void> disposeVoiceEvents() async {
    closeScreenPreviewSubscriptions();
    final listener = voiceEvents;
    voiceEvents = null;
    await listener?.dispose();
  }
}
