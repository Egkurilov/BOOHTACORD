import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import 'publication_generation.dart';
import 'recovery_deadline.dart';

mixin VoiceScreenViewerSelectionState {
  String? _selectedRemoteScreenViewerIdentity;
  String? get selectedRemoteScreenViewerIdentity =>
      _selectedRemoteScreenViewerIdentity;
  set selectedRemoteScreenViewerIdentity(String? identity) {
    if (_selectedRemoteScreenViewerIdentity == identity) return;
    _selectedRemoteScreenViewerIdentity = identity;
    screenViewerSelectionRevision++;
    remoteScreenViewerRecoveryTimer?.cancel();
    remoteScreenViewerRecoveryTimer = null;
    remoteScreenViewerRecoveryDeadline.pause();
    remoteScreenViewerRecoveryAttempt = 0;
    remoteScreenViewerRecoveryDeadline.reset();
    remoteScreenViewerRecoveryInFlightGeneration = null;
    remoteScreenViewerRecoveryPublication = null;
    remoteScreenViewerRecoveryIsCurrent = null;
    if (identity == null) {
      selectedRemoteScreenViewerGeneration = null;
      remoteScreenViewerFirstFrameGeneration = null;
      selectedRemoteScreenViewerPublication = null;
      selectedRemoteScreenViewerAudioPublication = null;
    }
  }

  int screenViewerSelectionRevision = 0;
  ScreenViewerPublicationGeneration? selectedRemoteScreenViewerGeneration;
  ScreenViewerPublicationGeneration? remoteScreenViewerFirstFrameGeneration;
  RemoteTrackPublication? selectedRemoteScreenViewerPublication;
  RemoteTrackPublication? selectedRemoteScreenViewerAudioPublication;
  Future<void> remoteScreenSubscriptionTail = Future<void>.value();
  Timer? remoteScreenViewerRecoveryTimer;
  int remoteScreenViewerRecoveryAttempt = 0;
  ScreenViewerRecoveryDeadline remoteScreenViewerRecoveryDeadline =
      ScreenViewerRecoveryDeadline();
  bool remoteScreenViewerForeground = true;
  RemoteTrackPublication? remoteScreenViewerRecoveryPublication;
  bool Function()? remoteScreenViewerRecoveryIsCurrent;
  ScreenViewerPublicationGeneration? remoteScreenViewerRecoveryInFlightGeneration;

  bool get remoteScreenViewerRecoveryExhausted =>
      remoteScreenViewerRecoveryAttempt >= 2 &&
      selectedRemoteScreenViewerGeneration != null &&
      remoteScreenViewerFirstFrameGeneration !=
          selectedRemoteScreenViewerGeneration &&
      remoteScreenViewerRecoveryInFlightGeneration !=
          selectedRemoteScreenViewerGeneration;
}
