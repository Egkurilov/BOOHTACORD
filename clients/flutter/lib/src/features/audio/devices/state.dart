import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../services/audio_preferences.dart';
import '../../../services/native_noise_suppression.dart';
import '../../../services/voice_audio_config.dart';
import '../../../core/session/scope.dart';
import 'platform.dart';
import '../microphone_controls/native.dart';

abstract class AudioDeviceState extends ChangeNotifier {
  AudioDeviceState({
    required this.readRoom,
    this.readAccountId,
    Future<List<MediaDevice>> Function()? loader,
    this.changes,
    this.nativeBootstrap,
    SessionScope? scope,
  }) : scope = scope ?? SessionScope(),
       loader = loader ?? enumerateAudioDevices;
  final SessionScope scope;
  final nativeMicrophone = NativeMicrophoneControls();
  bool microphoneVad = true;
  final nativeNoise = NativeNoiseSuppression();
  int nativeRecoveryRevision = 0;
  bool microphoneMutedIntent = true;
  NoiseSuppressionMode? captureNoiseOverride;
  final Room? Function() readRoom;
  final String? Function()? readAccountId;
  final Future<List<MediaDevice>> Function() loader;
  final Stream<List<MediaDevice>>? changes;

  /// Initializes the native audio device module before the first inventory.
  ///
  /// The callback is injected by the application so tests and non-desktop
  /// clients can keep using the existing loader without touching WebRTC.
  final Future<void> Function()? nativeBootstrap;
  Room? get room => readRoom();
  AudioPreferences? preferences;
  StreamSubscription<List<MediaDevice>>? subscription;
  int deviceRevision = 0;
  bool refreshQueued = false;
  Completer<void>? queuedAudioRefreshCompletion;
  bool refreshAfterCaptureRequested = false;
  bool isDisposed = false;
  List<MediaDevice> audioInputDevices = const [];
  List<MediaDevice> audioOutputDevices = const [];
  String? selectedAudioInputId;
  String? selectedAudioOutputId;
  AudioProcessingPreferences audioProcessing =
      const AudioProcessingPreferences();
  bool audioDevicesLoading = false;
  bool audioDeviceScanFailed = false;
  bool audioInputSwitching = false;
  bool audioOutputSwitching = false;
  int audioInputSwitchRevision = 0;
  int audioOutputSwitchRevision = 0;
  String? audioSettingsError;
  String? audioDeviceWarning;
  void cancelOperations() {
    deviceRevision++;
    audioInputSwitchRevision++;
    audioOutputSwitchRevision++;
    nativeRecoveryRevision++;
    nativeNoise.cancel();
    unawaited(nativeMicrophone.clear());
    microphoneMutedIntent = true;
    captureNoiseOverride = null;
    audioDevicesLoading = false;
    audioInputSwitching = false;
    audioOutputSwitching = false;
    _releaseQueuedAudioRefresh();
    refreshAfterCaptureRequested = false;
  }

  void _releaseQueuedAudioRefresh() {
    refreshQueued = false;
    final queuedRefresh = queuedAudioRefreshCompletion;
    queuedAudioRefreshCompletion = null;
    if (queuedRefresh != null && !queuedRefresh.isCompleted) {
      queuedRefresh.complete();
    }
  }

  void clearAccount() {
    cancelOperations();
    preferences = null;
    selectedAudioInputId = null;
    selectedAudioOutputId = null;
    audioDeviceWarning = null;
    audioProcessing = const AudioProcessingPreferences();
  }

  Future<void> applyMicrophoneControls({bool? agc});
  Future<void> refreshAudioDevices();
  void applyAudioDevices(List<MediaDevice> devices);
  Future<void> applyAndroidAdditions(
    List<MediaDevice> baseDevices,
    int revision,
  );

  AudioCaptureOptions get captureOptions => voiceAudioCaptureOptions(
    selectedAudioInputId,
    captureNoiseOverride == null
        ? audioProcessing
        : audioProcessing.copyWith(noiseSuppressionMode: captureNoiseOverride),
  );

  @override
  void notifyListeners() {
    if (!isDisposed) super.notifyListeners();
  }

  @override
  void dispose() {
    isDisposed = true;
    _releaseQueuedAudioRefresh();
    nativeNoise.dispose();
    nativeMicrophone.dispose();
    deviceRevision++;
    unawaited(subscription?.cancel());
    subscription = null;
    super.dispose();
  }
}
