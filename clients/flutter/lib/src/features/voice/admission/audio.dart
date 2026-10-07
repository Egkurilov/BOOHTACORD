import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../../../services/android_audio_devices.dart';
import '../../../services/voice_audio_config.dart';
import '../lifecycle/controller.dart';
import 'prepare.dart';

extension VoiceAdmissionAudio on VoiceController {
  void checkCurrentVoiceAdmission(
    SessionTicket ticket,
    int revision,
    String lease,
    int disconnectGeneration,
  ) {
    if (disconnect.generation != disconnectGeneration) {
      throw CancelledVoiceAdmission();
    }
    checkAdmission(ticket, revision, lease);
  }

  Future<void> prepareVoiceAudio(
    SessionTicket ticket,
    int revision,
    String lease,
    int disconnectGeneration,
  ) async {
    await loadVoiceVolumes(ticket, revision, lease);
    checkCurrentVoiceAdmission(ticket, revision, lease, disconnectGeneration);
    if (audio.nativeBootstrap != null) {
      await audio.bootstrap();
      checkCurrentVoiceAdmission(ticket, revision, lease, disconnectGeneration);
    }
  }

  Future<void> refreshVoiceAudioAfterConnect(
    SessionTicket ticket,
    int revision,
    String lease,
    int disconnectGeneration,
  ) async {
    if (audio.nativeBootstrap == null) {
      await audio.refreshAudioDevices();
      checkCurrentVoiceAdmission(ticket, revision, lease, disconnectGeneration);
    }
  }

  RoomOptions voiceRoomOptions() => RoomOptions(
    adaptiveStream: true,
    dynacast: true,
    defaultAudioCaptureOptions: audio.captureOptions,
    defaultAudioPublishOptions: voiceMicrophonePublishOptions,
    defaultAudioOutputOptions: AudioOutputOptions(
      deviceId:
          AndroidAudioDevices.isNativeOutputRoute(selectedAudioOutputId) ||
              (AndroidAudioDevices.isAndroid &&
                  selectedAudioOutputId == 'default')
          ? null
          : selectedAudioOutputId,
    ),
  );

  Future<void> selectVoiceOutput() async {
    if (AndroidAudioDevices.isNativeOutputRoute(selectedAudioOutputId) &&
        !await AndroidAudioDevices.selectNativeOutput(selectedAudioOutputId!)) {
      throw StateError('Android не смог выбрать сохранённый аудиовыход.');
    }
  }

  Future<void> applyVoiceOutputSelection(
    Room candidate,
  ) async {
    await selectVoiceOutput();
    if (audio.nativeBootstrap != null) return;
    if (AndroidAudioDevices.isNativeOutputRoute(selectedAudioOutputId)) return;
    if (AndroidAudioDevices.isAndroid) {
      await AndroidAudioDevices.clearNativeOutput();
      if (selectedAudioOutputId == 'default') return;
    }
    final outputId = selectedAudioOutputId;
    if (candidate.selectedAudioOutputDeviceId == outputId) return;
    final device = audio.audioOutputDevices
        .where((candidate) => candidate.deviceId == outputId)
        .firstOrNull;
    if (device != null) await audioOutputDeviceSetter(candidate, device);
  }
}
