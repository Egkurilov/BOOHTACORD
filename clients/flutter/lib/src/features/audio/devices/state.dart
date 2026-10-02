import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../services/audio_preferences.dart';
import '../../../core/session/scope.dart';
import 'platform.dart';

abstract class AudioDeviceState extends ChangeNotifier {
  AudioDeviceState({
    required this.readRoom,
    Future<List<MediaDevice>> Function()? loader,
    this.changes,
    SessionScope? scope,
  }) : scope = scope ?? SessionScope(),
       loader = loader ?? enumerateAudioDevices;
  final SessionScope scope;
  final Room? Function() readRoom;
  final Future<List<MediaDevice>> Function() loader;
  final Stream<List<MediaDevice>>? changes;
  Room? get room => readRoom();
  AudioPreferences? preferences;
  StreamSubscription<List<MediaDevice>>? subscription;
  int deviceRevision = 0;
  bool refreshQueued = false;
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
  String? audioSettingsError;
  String? audioDeviceWarning;
  void cancelOperations() {
    deviceRevision++;
    audioDevicesLoading = false;
    refreshQueued = false;
    refreshAfterCaptureRequested = false;
  }

  void clearAccount() {
    cancelOperations();
    preferences = null;
    selectedAudioInputId = null;
    selectedAudioOutputId = null;
    audioDeviceWarning = null;
    audioProcessing = const AudioProcessingPreferences();
  }

  Future<void> refreshAudioDevices();
  void applyAudioDevices(List<MediaDevice> devices);
  Future<void> applyAndroidAdditions(
    List<MediaDevice> baseDevices,
    int revision,
  );

  AudioCaptureOptions get captureOptions => AudioCaptureOptions(
    deviceId: selectedAudioInputId,
    autoGainControl: audioProcessing.autoGainControl,
    echoCancellation: audioProcessing.echoCancellation,
    noiseSuppression: audioProcessing.noiseSuppression,
  );

  @override
  void notifyListeners() {
    if (!isDisposed) super.notifyListeners();
  }

  @override
  void dispose() {
    isDisposed = true;
    deviceRevision++;
    unawaited(subscription?.cancel());
    subscription = null;
    super.dispose();
  }
}
