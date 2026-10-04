import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/features/voice/shortcuts/model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const microphone = VoiceShortcutBinding(
    keyId: 109,
    label: 'KeyM',
    physicalKeyId: 0x70010,
    control: true,
    alt: true,
  );
  const deafen = VoiceShortcutBinding(
    keyId: 100,
    label: 'KeyD',
    physicalKeyId: 0x70007,
    control: true,
    alt: true,
  );
  test('physical shortcuts persist by account and reset together without erasing PTT', () async {
    SharedPreferences.setMockInitialValues({});
    final alice = await AudioPreferences.open('a');
    await alice.setPttKey(32, 'Space');
    await alice.setMicrophoneShortcut(microphone);
    await alice.setDeafenShortcut(deafen);
    expect((await AudioPreferences.open('a')).microphoneShortcut, microphone);
    expect((await AudioPreferences.open('b')).microphoneShortcut, isNull);
    await alice.resetVoiceShortcuts();
    final reset = await AudioPreferences.open('a');
    expect(reset.microphoneShortcut, isNull);
    expect(reset.deafenShortcut, isNull);
    expect(reset.pttKeyId, 32);
  });
  test('typed bindings reject malformed modifiers and identify physical/legacy conflicts', () {
    expect(
      () => VoiceShortcutBinding.fromJson({
        ...microphone.toJson(),
        'control': 'yes',
      }),
      throwsFormatException,
    );
    expect(
      () => VoiceShortcutBinding.fromJson({
        ...microphone.toJson(),
        'physicalKeyId': 'M',
      }),
      throwsFormatException,
    );
    final legacy = VoiceShortcutBinding(
      keyId: LogicalKeyboardKey.keyM.keyId,
      label: 'M',
      control: true,
      alt: true,
    );
    expect(voiceShortcutConflict(microphone, legacy, null), 'duplicate');
    expect(
      voiceShortcutConflict(microphone, null, LogicalKeyboardKey.keyM.keyId),
      'ptt',
    );
    const reserved = VoiceShortcutBinding(
      keyId: 119,
      label: 'KeyW',
      physicalKeyId: 0x7001a,
      control: true,
    );
    expect(voiceShortcutConflict(reserved, null, null), 'reserved');
    expect(
      voiceShortcutConflict(
        const VoiceShortcutBinding(
          keyId: 107,
          label: 'KeyK',
          physicalKeyId: 0x7000e,
          control: true,
          alt: true,
        ),
        null,
        null,
      ),
      'search',
    );
  });
}
