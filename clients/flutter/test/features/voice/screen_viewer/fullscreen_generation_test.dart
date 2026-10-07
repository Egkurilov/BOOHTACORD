import 'dart:collection';

import 'package:boohtacord_desktop/src/features/voice/screen_viewer/fullscreen_generation.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_viewer/publication_generation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

class _ScreenPublication extends Fake implements RemoteTrackPublication {
  _ScreenPublication(this.sid, {this.subscriptionAllowed = true});
  @override
  final String sid;
  @override
  final bool subscriptionAllowed;
  @override
  TrackSource get source => TrackSource.screenShareVideo;
  @override
  bool get muted => false;
}
class _RemotePeer extends Fake implements RemoteParticipant {
  _RemotePeer(this.identity, this.videoTrackPublications);
  @override
  final String identity;
  @override
  final List<RemoteTrackPublication> videoTrackPublications;
}
class _Room extends Fake implements Room {
  _Room(this.localParticipant, this.remoteParticipants);
  @override
  final LocalParticipant localParticipant;
  @override
  final UnmodifiableMapView<String, RemoteParticipant> remoteParticipants;
}
class _LocalPublication extends Fake
    implements LocalTrackPublication<LocalVideoTrack> {
  _LocalPublication(this.sid, this.track);
  @override
  final String sid;
  @override
  final LocalVideoTrack track;
}
class _LocalPeer extends Fake implements LocalParticipant {
  _LocalPeer(this.publication);
  final LocalTrackPublication<LocalVideoTrack> publication;
  @override
  LocalTrackPublication? getTrackPublicationBySource(TrackSource source) =>
      publication;
}
class _LocalTrack extends Fake implements LocalVideoTrack {}

void main() {
  test('remote route closes on republish, revocation, or room replacement', () {
    const oldGeneration = ScreenViewerPublicationGeneration(
      participantIdentity: 'peer',
      publicationSid: 'old-sid',
    );
    final oldRoom = _remoteRoom('peer', 'old-sid');
    final republishedRoom = _remoteRoom('peer', 'new-sid');
    final revokedRoom = _remoteRoom('peer', 'old-sid', allowed: false);
    final replacedRoom = _remoteRoom('peer', 'old-sid');

    expect(_remoteCurrent(oldRoom, oldGeneration), isTrue);
    expect(_remoteCurrent(republishedRoom, oldGeneration), isFalse);
    expect(_remoteCurrent(revokedRoom, oldGeneration), isFalse);
    expect(
      _remoteCurrent(replacedRoom, oldGeneration, capturedRoom: oldRoom),
      isFalse,
    );
  });
  test('local capture uses its SID and fallback track generation', () {
    final track = _LocalTrack();
    const sid = 'local-sid';
    expect(
      localScreenFullscreenGeneration(publicationSid: sid, track: track),
      sid,
    );
    expect(
      localScreenFullscreenGeneration(publicationSid: null, track: track),
      same(track),
    );
  });
  test('local route follows SID and closes on replacement or stop', () {
    final current = _localRoom('old-sid');
    final replacement = _localRoom('new-sid');
    expect(_localCurrent(current, 'old-sid'), isTrue);
    expect(_localCurrent(replacement, 'old-sid'), isFalse);
    expect(_localCurrent(current, 'old-sid', active: false), isFalse);
  });
}
_Room _remoteRoom(String identity, String sid, {bool allowed = true}) => _Room(
  _LocalPeer(_LocalPublication('unused', _LocalTrack())),
  UnmodifiableMapView({
    identity: _RemotePeer(identity, [
      _ScreenPublication(sid, subscriptionAllowed: allowed),
    ]),
  }),
);
bool _remoteCurrent(Room room, Object generation, {Room? capturedRoom}) =>
    screenFullscreenGenerationIsPublished(
      room: room,
      capturedRoom: capturedRoom ?? room,
      publisherIdentity: 'peer',
      viewerGeneration: generation,
      localCaptureActive: false,
    );
_Room _localRoom(String sid) => _Room(
  _LocalPeer(_LocalPublication(sid, _LocalTrack())),
  UnmodifiableMapView(const {}),
);

bool _localCurrent(Room room, Object generation, {bool active = true}) =>
    screenFullscreenGenerationIsPublished(
      room: room,
      capturedRoom: room,
      publisherIdentity: null,
      viewerGeneration: generation,
      localCaptureActive: active,
    );
