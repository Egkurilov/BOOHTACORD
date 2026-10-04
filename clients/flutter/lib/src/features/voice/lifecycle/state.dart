import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../../../models.dart';
import '../../../services/api_client.dart';
import '../../../services/audio_preferences.dart';
import '../../../services/voice_volume_preferences.dart';
import '../../../services/voice_stream_start_tracker.dart';
import '../../../services/screen_thumbnail.dart';
import '../../audio/devices/controller.dart';
import '../../screen/lifecycle/controller.dart';
import '../microphone/shortcut.dart';
import 'types.dart';

abstract class VoiceState extends ChangeNotifier {
  VoiceState(
    this.api,
    this.scope,
    this.audio,
    this.screen, {
    required this.readUser,
    required this.reportError,
    required this.formatError,
    required this.createRoom,
  });
  final ApiClient api;
  final SessionScope scope;
  final AudioDeviceController audio;
  final ScreenShareController screen;
  final SessionUser? Function() readUser;
  final void Function(String?) reportError;
  final String Function(Object) formatError;
  final Room Function(RoomOptions) createRoom;
  set error(String? value) => reportError(value);
  bool disposed = false;
  int operationRevision = 0;
  int microphoneRevision = 0;
  Future<void> microphoneTail = Future<void>.value();
  Future<void>? closing;
  Room? pendingRoom;
  bool active(SessionTicket ticket, int revision) =>
      !disposed && ticket.isActive && revision == operationRevision;
  @override
  void notifyListeners() {
    if (!disposed) super.notifyListeners();
  }

  VoicePhase voicePhase = VoicePhase.idle;
  GuildChannel? voiceChannel;
  bool microphoneMuted = false;
  bool microphoneUnavailable = false;
  bool deafened = false;
  bool deafenChanging = false;
  bool voiceStreamSoundEnabled = true;
  bool voiceStreamStartNotice = false;
  AudioActivationMode audioActivationMode = AudioActivationMode.vad;
  int? pushToTalkKeyId;
  String? pushToTalkKeyLabel;
  VoiceShortcutBinding? microphoneShortcut;
  VoiceShortcutBinding? deafenShortcut;
  String? voiceShortcutStatus;
  String? audioActivationError;
  bool pushToTalkPressed = false;
  bool get usesTouchPushToTalk =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  bool mutedBeforeDeafen = false;
  bool microphoneMutedBeforePtt = false;
  Room? room;
  int? voicePingMs;
  EventsListener<RoomEvent>? voiceEvents;
  VoiceVolumePreferences? voiceVolumePreferences;
  final Set<String> mutedScreenShareAudioIdentities = <String>{};
  final Map<String, int> transientScreenShareVolumes = <String, int>{};
  AudioPreferences? get audioPreferences => audio.preferences;
  set audioPreferences(AudioPreferences? value) => audio.preferences = value;
  String? leaseId;
  bool listenerOnly = false;
  bool voiceAdmissionPending = false;
  final Map<String, String> revokedVoiceLeasesDuringJoin = {};
  Timer? voiceStreamNoticeTimer;
  Timer? voiceConnectionStatsTimer;
  int voiceConnectionStatsRevision = 0;
  bool voiceConnectionStatsBusy = false;
  final VoiceStreamStartTracker voiceStreamStartTracker =
      VoiceStreamStartTracker();
  ScreenThumbnailCaptureQueue get screenThumbnailCaptureQueue =>
      screen.captureQueue;
  ScreenPreviewSubscriptionQueue? screenPreviewSubscriptionQueue;
  final Map<String, Completer<RemoteVideoTrack?>> screenPreviewTrackWaiters =
      <String, Completer<RemoteVideoTrack?>>{};
  String? selectedRemoteScreenViewerIdentity;
  final Map<String, String> screenThumbnailRemoteTrackIds = <String, String>{};
  String? get selectedAudioInputId => audio.selectedAudioInputId;
  set selectedAudioInputId(String? value) => audio.selectedAudioInputId = value;
  String? get selectedAudioOutputId => audio.selectedAudioOutputId;
  set selectedAudioOutputId(String? value) =>
      audio.selectedAudioOutputId = value;
  AudioProcessingPreferences get audioProcessing => audio.audioProcessing;
  set audioProcessing(AudioProcessingPreferences value) =>
      audio.audioProcessing = value;
  String? get audioSettingsError => audio.audioSettingsError;
  set audioSettingsError(String? value) => audio.audioSettingsError = value;
  ScreenSharePhase get screenSharePhase => screen.phase;
  set screenSharePhase(ScreenSharePhase value) => screen.phase = value;
  String? get screenShareError => screen.error;
  set screenShareError(String? value) => screen.error = value;
  Map<String, Uint8List> get screenThumbnails => screen.thumbnails;
}
