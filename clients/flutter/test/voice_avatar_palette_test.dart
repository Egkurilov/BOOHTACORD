import 'package:boohtacord_desktop/src/services/voice_avatar_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the same FNV avatar palette mapping as the web client', () {
    expect(voiceAvatarPaletteIndex('account-2'), 0);
    expect(voiceAvatarPaletteIndex('account-1'), 4);
    expect(voiceAvatarPaletteIndex('abc'), 1);
    expect(voiceAvatarPaletteIndex('member-9'), 3);
  });
}
