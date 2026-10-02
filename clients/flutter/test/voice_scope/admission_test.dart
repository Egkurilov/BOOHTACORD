import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';

import 'fakes.dart';

const channel = GuildChannel(
  id: 'voice',
  name: 'Voice',
  kind: ChannelKind.voice,
  admissionClosed: false,
);
const credential = VoiceCredential(
  url: 'wss://voice.invalid',
  token: 'test-only',
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('logout during credential request prevents Room creation', () async {
    final h = VoiceHarness();
    addTearDown(h.dispose);
    final joining = h.owner.joinVoice(channel);
    await Future<void>.delayed(Duration.zero);
    h.scope.close();
    await h.owner.leaveVoice();
    h.api.credential.complete(('lease', credential));
    await joining;
    expect(h.created, 0);
    expect(h.owner.room, isNull);
    expect(h.owner.voicePhase, VoicePhase.idle);
    expect(h.error, isNull);
  });
  test('revocation during connect cannot enable the microphone', () async {
    final h = VoiceHarness();
    addTearDown(h.dispose);
    h.api.credential.complete(('lease', credential));
    final joining = h.owner.joinVoice(channel);
    await Future<void>.delayed(Duration.zero);
    expect(h.room.connectCalled, isTrue);
    h.owner.dispatchVoiceRevocation({'lease_id': 'lease', 'reason': 'KICK'});
    h.room.connecting.complete();
    await joining;
    expect(h.room.localParticipant.enabled, isEmpty);
    expect(h.room.disconnected, greaterThan(0));
    expect(h.owner.room, isNull);
    expect(h.owner.voicePhase, VoicePhase.error);
    expect(h.error, 'Администратор отключил вас от голосового канала.');
  });
  test('a late connected room is disconnected after logout', () async {
    final h = VoiceHarness();
    addTearDown(h.dispose);
    h.api.credential.complete(('lease', credential));
    final joining = h.owner.joinVoice(channel);
    await Future<void>.delayed(Duration.zero);
    h.scope.close();
    await h.owner.leaveVoice();
    final disconnectedAtLogout = h.room.disconnected;
    h.room.connecting.complete();
    await joining;
    expect(h.room.disconnected, greaterThan(disconnectedAtLogout));
    expect(h.owner.voicePhase, VoicePhase.idle);
    expect(h.room.localParticipant.enabled, isEmpty);
  });
}
