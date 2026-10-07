import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import 'publication_generation.dart';

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
    remoteScreenViewerRecoveryAttempt = 0;
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
  int remoteScreenViewerRendererRevision = 0;
}
