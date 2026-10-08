import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/roster_display/live_members.dart';

class OverlayPeer implements RemoteParticipant {
  @override
  final String name = 'Current peer';
  @override
  final String metadata = 'account:current';
  @override
  bool isMicrophoneEnabled() => false;
  @override
  bool isScreenShareEnabled() => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class OverlayRoom implements Room {
  final peers = <String, RemoteParticipant>{'peer': OverlayPeer()};
  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView(peers);
  @override
  LocalParticipant? get localParticipant => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('current Room removes stale roster members and supplies truthful microphone state', () {
    final room = OverlayRoom();
    const roster = VoiceRoomRoster(
      channelId: 'voice',
      participants: [
        VoiceRosterMember(
          accountId: 'current',
          displayName: 'Cached peer',
          screenSharing: false,
          microphoneMuted: false,
        ),
        VoiceRosterMember(
          accountId: 'left',
          displayName: 'Departed',
          screenSharing: false,
          microphoneMuted: false,
        ),
      ],
    );
    final members = liveOverlayMembers(room, roster, null, true);
    expect(members.map((p) => p.accountId), ['current']);
    expect(members.single.displayName, 'Cached peer');
    expect(members.single.microphoneMuted, isTrue);
    room.peers.clear();
    expect(liveOverlayMembers(room, roster, null, true), isEmpty);
  });
  test('joined Room supplies participant names even before roster SSE is available', () {
    final members = liveOverlayMembers(OverlayRoom(), null, null, true);
    expect(members.single.displayName, 'Current peer');
  });
}
