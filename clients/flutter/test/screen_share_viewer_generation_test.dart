import 'package:boohtacord_desktop/src/features/voice/screen_viewer/discovery.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_viewer/publication_generation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

class _RemotePublication extends Fake implements RemoteTrackPublication {
  _RemotePublication({required this.source, required this.muted, required this.sid});

  @override
  final TrackSource source;
  @override
  final bool muted;
  @override
  final String sid;
  @override
  RemoteTrack? get track => null;
}

void main() {
  test('published screen is discoverable before auto subscription adds a track', () {
    final publication = _RemotePublication(
      source: TrackSource.screenShareVideo,
      muted: false,
      sid: 'TR_screen_generation_1',
    );

    expect(publication.track, isNull);
    expect(isDiscoverableRemoteScreenPublication(publication), isTrue);
    expect(
      isDiscoverableRemoteScreenPublication(
        _RemotePublication(
          source: TrackSource.screenShareVideo,
          muted: true,
          sid: 'TR_screen_muted',
        ),
      ),
      isFalse,
    );
  });

  test('publication SID is the idempotency generation, not mutable metadata', () {
    const initial = ScreenViewerPublicationGeneration(
      participantIdentity: 'publisher',
      publicationSid: 'TR_screen_generation_1',
    );
    const metadataRefresh = ScreenViewerPublicationGeneration(
      participantIdentity: 'publisher',
      publicationSid: 'TR_screen_generation_1',
    );
    const republished = ScreenViewerPublicationGeneration(
      participantIdentity: 'publisher',
      publicationSid: 'TR_screen_generation_2',
    );

    expect(metadataRefresh, initial);
    expect(republished, isNot(initial));
  });
}
