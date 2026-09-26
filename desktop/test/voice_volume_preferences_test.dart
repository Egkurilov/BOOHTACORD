import 'dart:convert';

import 'package:boohtacord_desktop/src/services/voice_volume_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('keeps participant levels per signed-in and remote account', () async {
    SharedPreferences.setMockInitialValues({});
    final owner = await VoiceVolumePreferences.open('owner');
    final other = await VoiceVolumePreferences.open('other');

    await owner.setParticipant('remote-a', 175);
    await owner.setParticipant('remote-b', 25);

    expect(owner.participant('remote-a'), 175);
    expect(owner.participant('remote-b'), 25);
    expect(other.participant('remote-a'), 100);
    expect(
      (await VoiceVolumePreferences.open('owner')).participant('remote-a'),
      175,
    );
  });

  test('clamps levels and preserves a saved screen level', () async {
    SharedPreferences.setMockInitialValues({
      'voice-volume:v1:owner:remote-a': jsonEncode({
        'participant': 250,
        'screen': 160,
      }),
    });
    final preferences = await VoiceVolumePreferences.open('owner');
    expect(preferences.participant('remote-a'), 200);

    await preferences.setParticipant('remote-a', -20);
    await preferences.setScreen('remote-a', 190);

    expect(preferences.participant('remote-a'), 0);
    expect(preferences.screen('remote-a'), 190);
    final storage = await SharedPreferences.getInstance();
    expect(jsonDecode(storage.getString('voice-volume:v1:owner:remote-a')!), {
      'participant': 0,
      'screen': 190,
    });
  });

  test('fast changes persist the final level', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await VoiceVolumePreferences.open('owner');

    await Future.wait([
      for (final level in [40, 70, 125, 190])
        preferences.setParticipant('remote-a', level),
    ]);

    expect(
      (await VoiceVolumePreferences.open('owner')).participant('remote-a'),
      190,
    );
  });
}
