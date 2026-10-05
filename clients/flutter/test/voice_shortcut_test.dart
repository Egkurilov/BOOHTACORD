import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boohtacord_desktop/src/features/voice/microphone/shortcut.dart';

void main() {
  test('formats named legacy logical keys without labels', () {
    expect(
      VoiceShortcutBinding(keyId: LogicalKeyboardKey.tab.keyId, label: '')
          .code,
      'Tab',
    );
    expect(
      VoiceShortcutBinding(keyId: LogicalKeyboardKey.escape.keyId, label: '')
          .code,
      'Escape',
    );
  });

  test('validates, formats and serializes modifier shortcuts', () {
    const binding = VoiceShortcutBinding(keyId: 42, label: 'M', control: true);
    expect(binding.isValid, isTrue);
    expect(formatVoiceShortcut(binding), 'Ctrl+M');
    expect(VoiceShortcutBinding.fromJson(binding.toJson()), binding);

    for (final modifier in [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.metaRight,
    ]) {
      expect(
        VoiceShortcutBinding(
          keyId: modifier.keyId,
          label: modifier.keyLabel,
          control: true,
        ).isValid,
        isFalse,
      );
    }
  });

  test('identifies modifier keys while capturing a shortcut', () {
    for (final modifier in [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
    ]) {
      expect(isVoiceShortcutModifierKey(modifier), isTrue);
    }
    expect(isVoiceShortcutModifierKey(LogicalKeyboardKey.keyM), isFalse);
  });

  test('rejects bare alphanumeric and conflicts with PTT/search', () {
    const bare = VoiceShortcutBinding(keyId: 42, label: 'M');
    final search = VoiceShortcutBinding(
      keyId: LogicalKeyboardKey.keyK.keyId,
      label: 'K',
      control: true,
    );
    expect(bare.isValid, isFalse);
    expect(voiceShortcutConflict(search, null, null), 'search');
    expect(voiceShortcutConflict(const VoiceShortcutBinding(keyId: 42, label: 'M', alt: true), null, 42), 'ptt');
  });
}
