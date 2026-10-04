import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';
import 'voice_scope/fakes.dart';
import 'voice_scope/api.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final serverFirst in [true, false]) {
    test('controller preserves kick with serverFirst=$serverFirst', () async {
      final h = VoiceHarness(); addTearDown(h.dispose);
      h.owner.room = h.room; h.owner.leaseId = 'lease'; h.owner.voiceChannel = channel;
      h.owner.voicePhase = VoicePhase.connected;
      if (serverFirst) {
        await h.owner.handleVoiceLeaseRevoked('lease', 'KICK');
        await h.owner.handleUnexpectedVoiceDisconnect(h.room, RoomDisconnectedEvent(reason: DisconnectReason.reconnectAttemptsExceeded));
      } else {
        await h.owner.handleUnexpectedVoiceDisconnect(h.room, RoomDisconnectedEvent(reason: DisconnectReason.reconnectAttemptsExceeded));
        h.owner.dispatchVoiceRevocation({'lease_id': 'lease', 'reason': 'KICK'});
      }
      h.owner.dispatchVoiceRevocation({'lease_id': 'lease', 'reason': 'KICK'});
      expect(h.owner.disconnect.notice?.reason, 'KICK');
      expect(h.error, 'Администратор отключил вас от голосового канала.');
      expect(h.owner.voicePhase, VoicePhase.error); expect(h.owner.room, isNull);
      expect(h.owner.disconnect.notice?.reconnectAllowed, isTrue);
      h.owner.selectDisconnectChannel('other'); expect(h.owner.disconnect.notice, isNull);
      h.owner.dispatchVoiceRevocation({'lease_id': 'lease', 'reason': 'KICK'});
      expect(h.owner.disconnect.notice, isNull);
    });
  }
  test('kick during credential admission preserves terminal notice', () async {
    final h = VoiceHarness(); addTearDown(h.dispose);
    final joining = h.owner.joinVoice(channel); await Future<void>.delayed(Duration.zero);
    h.owner.dispatchVoiceRevocation({'lease_id': 'lease', 'reason': 'KICK'});
    h.owner.dispatchVoiceRevocation({'lease_id': 'foreign', 'reason': 'BANNED'});
    h.api.credential.complete(('lease', credential)); await joining;
    expect(h.created, 0); expect(h.owner.disconnect.notice?.reason, 'KICK');
    expect(h.error, 'Администратор отключил вас от голосового канала.');
  });
  test('local exit has precedence over a late transport callback', () async {
    final h = VoiceHarness(); addTearDown(h.dispose);
    h.owner.room = h.room; h.owner.leaseId = 'lease'; h.owner.voiceChannel = channel;
    h.owner.voicePhase = VoicePhase.connected;
    await h.owner.leaveVoice();
    await h.owner.handleUnexpectedVoiceDisconnect(h.room, RoomDisconnectedEvent());
    expect(h.owner.disconnect.notice?.source, 'local'); expect(h.error, isNull);
    expect(h.owner.voicePhase, VoicePhase.idle);
  });

  test('channel selection during rejected join clears the old cause', () async {
    final h = VoiceHarness(); addTearDown(h.dispose);
    final joining = h.owner.joinVoice(channel);
    await Future<void>.delayed(Duration.zero);
    h.api.credential.complete(('lease', credential));
    await Future<void>.delayed(Duration.zero);
    expect(h.room.connectCalled, isTrue);
    h.owner.dispatchVoiceRevocation({'lease_id': 'lease', 'reason': 'KICK'});
    h.owner.selectDisconnectChannel('other');
    h.room.connecting.complete(); await joining;
    expect(h.owner.disconnect.notice, isNull); expect(h.error, isNull);
    expect(h.owner.room, isNull); expect(h.owner.voicePhase, VoicePhase.idle);
  });

}
