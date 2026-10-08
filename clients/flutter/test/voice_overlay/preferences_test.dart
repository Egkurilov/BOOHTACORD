import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to showing the full roster and saves the selection', () async {
    final preferences = await VoiceOverlayPreferences.open('account-a');

    expect(preferences.onlySpeakers, isFalse);
    await preferences.setOnlySpeakers(true);
    final restored = await VoiceOverlayPreferences.open('account-a');

    expect(restored.onlySpeakers, isTrue);
  });

  test('keeps the filter separate for each account', () async {
    final first = await VoiceOverlayPreferences.open('account-a');
    final second = await VoiceOverlayPreferences.open('account-b');

    await first.setOnlySpeakers(true);

    expect((await VoiceOverlayPreferences.open('account-a')).onlySpeakers,
        isTrue);
    expect((await VoiceOverlayPreferences.open('account-b')).onlySpeakers,
        isFalse);
    expect(second.onlySpeakers, isFalse);
  });
}
