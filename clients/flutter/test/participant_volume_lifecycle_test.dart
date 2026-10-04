import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/preferences/clear.dart';
import 'package:boohtacord_desktop/src/services/voice_volume_preferences.dart';
import 'voice_scope/fakes.dart';
class Peer implements RemoteParticipant {
  Peer(this.identity, this.name);
  @override final String identity;
  @override final String name;
  @override String? get metadata => 'account:stable-peer';
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('SID and rename use stable account preferences; logout flushes the old owner', () async {
    SharedPreferences.setMockInitialValues({});
    final h = VoiceHarness(); addTearDown(h.dispose);
    const origin = 'https://guild.example';
    final prefs = await VoiceVolumePreferences.open('owner', origin: origin);
    h.owner.voiceVolumePreferences = prefs;
    final saving = prefs.setParticipant('stable-peer', 175);
    expect(h.owner.participantVolume(Peer('old-sid', 'Alice')), 175);
    expect(h.owner.participantVolume(Peer('new-sid', 'Renamed')), 175);
    h.owner.clearAccountPreferences(); await saving;
    h.owner.voiceVolumePreferences = await VoiceVolumePreferences.open('other', origin: origin);
    expect(h.owner.participantVolume(Peer('another-sid', 'Alice')), 100);
    h.owner.voiceVolumePreferences = await VoiceVolumePreferences.open('owner', origin: origin);
    expect(h.owner.participantVolume(Peer('rejoined-sid', 'Alice')), 175);
  });
}
