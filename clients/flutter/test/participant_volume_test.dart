import 'dart:convert';
import 'package:boohtacord_desktop/src/services/voice_volume_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
void main() {
  const origin = 'https://guild.example/api/v1';
  test('origin/account isolation and reset include inactive participants', () async {
    SharedPreferences.setMockInitialValues({});
    final owner = await VoiceVolumePreferences.open('owner', origin: origin);
    await owner.setParticipant('inactive', 175);
    await owner.setScreen('inactive', 60);
    expect((await VoiceVolumePreferences.open('owner', origin: 'https://other.example')).participant('inactive'), 100);
    expect((await VoiceVolumePreferences.open('other', origin: origin)).participant('inactive'), 100);
    final restored = await VoiceVolumePreferences.open('owner', origin: 'https://guild.example/');
    expect(restored.participant('inactive'), 175);
    await restored.reset();
    final reopened = await VoiceVolumePreferences.open('owner', origin: origin);
    expect(reopened.participant('inactive'), 100);
    expect(reopened.screen('inactive'), 100);
  });
  test('normalizes 0/100/200, malformed values and corrupt documents', () async {
    for (final level in [0, 100, 200]) { expect(VoiceVolumePreferences.normalize(level), level); }
    expect(VoiceVolumePreferences.normalize(double.nan), 100);
    expect(VoiceVolumePreferences.normalize(-1), 0);
    expect(VoiceVolumePreferences.normalize(250), 200);
    final key = 'voice-volume:v2:https%3A%2F%2Fguild.example:owner';
    SharedPreferences.setMockInitialValues({key: 'not-json'});
    final corrupt = await VoiceVolumePreferences.open('owner', origin: origin);
    expect(corrupt.participant('peer'), 100); expect(corrupt.status, 'fallback');
    SharedPreferences.setMockInitialValues({key: jsonEncode({'version': 2, 'volumes': {'peer': {'participant': '175'}}})});
    expect((await VoiceVolumePreferences.open('owner', origin: origin)).participant('peer'), 100);
  });
  test('flush coalesces updates before debounce without changing the current gain', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await VoiceVolumePreferences.open('owner', origin: origin);
    final writes = [for (final value in [0, 100, 175, 200]) prefs.setParticipant('peer', value)];
    expect(prefs.participant('peer'), 200);
    expect((await SharedPreferences.getInstance()).getString(prefs.key), isNull);
    await prefs.flush(); await Future.wait(writes);
    expect((await VoiceVolumePreferences.open('owner', origin: origin)).participant('peer'), 200);
  });
  test('originless legacy preferences never leak into a deployment', () async {
    SharedPreferences.setMockInitialValues({'voice-volume:v1:owner:peer': jsonEncode({'participant': 175})});
    expect((await VoiceVolumePreferences.open('owner', origin: origin)).participant('peer'), 100);
  });
  test('blocked storage remains usable and reports fallback', () async {
    final prefs = VoiceVolumePreferences(null, 'owner', origin: origin);
    expect(prefs.participant('remote'), 100);
    final pending = prefs.setParticipant('remote', 200);
    expect(prefs.participant('remote'), 200);
    await expectLater(pending, throwsStateError);
    expect(prefs.status, 'fallback');
    await expectLater(prefs.reset(), throwsStateError);
    expect(prefs.participant('remote'), 100);
  });
}
