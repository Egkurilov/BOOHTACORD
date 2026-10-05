import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/audio_diagnostics/model.dart';
void main() {
  test('safe report projects fields instead of forwarding arbitrary SDK data', () {
    final value = VoiceAudioDiagnostics('baseline-128-v1', 128000,
      {'sampleRate': 48000, 'channels': 1, 'agc': true, 'deviceId': 'private-marker', 'label': 'private-marker'},
      [{'direction': 'sender', 'codec': 'opus', 'bitrateBps': 64000,
        'audioLevel': 0.12345, 'ssrc': 'private-marker', 'trackId': 'private-marker', 'pcm': 'private-marker'}]);
    final json = jsonEncode(value.toSafeJson());
    expect(json, isNot(contains('private-marker'))); expect(json, isNot(contains('audioLevel')));
    expect((value.toSafeJson()['samples'] as List).single['bitrateBps'], 64000);
  });
  test('untrusted profile and codec labels are not exported', () {
    final value = VoiceAudioDiagnostics('private-marker', 128000, {},
      [{'direction': 'receiver', 'codec': 'private-marker'}]);
    expect(jsonEncode(value.toSafeJson()), isNot(contains('private-marker')));
  });
}
