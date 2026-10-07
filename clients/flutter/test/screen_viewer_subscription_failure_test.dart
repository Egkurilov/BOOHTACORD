import 'package:boohtacord_desktop/src/features/voice/screen_viewer/publication_generation.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_viewer/subscription_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test('subscription failure matches only the selected publication SID', () {
    const generation = ScreenViewerPublicationGeneration(
      participantIdentity: 'publisher',
      publicationSid: 'screen-1',
    );
    const matching = TrackSubscriptionExceptionEvent(
      sid: 'screen-1',
      reason: TrackSubscribeFailReason.invalidServerResponse,
    );
    const stale = TrackSubscriptionExceptionEvent(
      sid: 'screen-2',
      reason: TrackSubscribeFailReason.invalidServerResponse,
    );
    const unidentified = TrackSubscriptionExceptionEvent(
      reason: TrackSubscribeFailReason.invalidServerResponse,
    );

    expect(matchesRemoteScreenViewerSubscriptionFailure(generation, matching),
        isTrue);
    expect(matchesRemoteScreenViewerSubscriptionFailure(generation, stale),
        isFalse);
    expect(
      matchesRemoteScreenViewerSubscriptionFailure(generation, unidentified),
      isFalse,
    );
  });
}
