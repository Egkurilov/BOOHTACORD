import 'package:boohtacord_desktop/src/features/voice/screen_viewer/publication_generation.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_viewer/selection_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _SelectionState with VoiceScreenViewerSelectionState {}

void main() {
  test('manual recovery appears only after the one automatic attempt settles',
      () {
    const generation = ScreenViewerPublicationGeneration(
      participantIdentity: 'publisher',
      publicationSid: 'screen-1',
    );
    final state = _SelectionState()
      ..selectedRemoteScreenViewerGeneration = generation
      ..remoteScreenViewerRecoveryAttempt = 2;

    expect(state.remoteScreenViewerRecoveryExhausted, isTrue);
    state.remoteScreenViewerRecoveryInFlightGeneration = generation;
    expect(state.remoteScreenViewerRecoveryExhausted, isFalse);
    state.remoteScreenViewerRecoveryInFlightGeneration = null;
    state.remoteScreenViewerFirstFrameGeneration = generation;
    expect(state.remoteScreenViewerRecoveryExhausted, isFalse);
  });
}
