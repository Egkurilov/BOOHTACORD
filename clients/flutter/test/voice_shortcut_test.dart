import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boohtacord_desktop/src/features/voice/microphone/shortcut.dart';

void main() {
  test('validates, formats and serializes modifier shortcuts', () {
    const binding = VoiceShortcutBinding(keyId: 42, label: 'M', control: true);
    expect(binding.isValid, isTrue);
    expect(formatVoiceShortcut(binding), 'Ctrl+M');
    expect(VoiceShortcutBinding.fromJson(binding.toJson()), binding);
  });

  test('rejects bare alphanumeric and conflicts with PTT/search', () {
    const bare = VoiceShortcutBinding(keyId: 42, label: 'M');
    const search = VoiceShortcutBinding(keyId: LogicalKeyboardKey.keyK.keyId, label: 'K', control: true);
    expect(bare.isValid, isFalse);
    expect(voiceShortcutConflict(search, null, null), 'search');
    expect(voiceShortcutConflict(const VoiceShortcutBinding(keyId: 42, label: 'M', alt: true), null, 42), 'ptt');
  });
}
