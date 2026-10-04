import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/features/audio/preferences/microphone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('safe migration and numeric normalization', () {
    expect(MicrophoneSettings.fromJson({}).vadThresholdDb, -50);
    final settings = MicrophoneSettings.fromJson({
      'vadThresholdDb': double.nan, 'microphoneGainPercent': 999,
    });
    expect(settings.vadThresholdDb, -50);
    expect(settings.microphoneGainPercent, 200);
    expect(MicrophoneSettings.fromJson({'microphoneGainPercent': '200'}).microphoneGainPercent, 100);
  });
  test('account isolation and manual gain survives AGC changes', () async {
    SharedPreferences.setMockInitialValues({});
    final one = await AudioPreferences.open('one');
    await one.setMicrophoneSettings(const MicrophoneSettings(vadThresholdDb: -43, microphoneGainPercent: 175));
    await one.setProcessing(const AudioProcessingPreferences(autoGainControl: true));
    final restored = await AudioPreferences.open('one');
    expect(restored.microphone.microphoneGainPercent, 175);
    expect(restored.microphone.vadThresholdDb, -43);
    expect((await AudioPreferences.open('two')).microphone.microphoneGainPercent, 100);
    await restored.setProcessing(const AudioProcessingPreferences(autoGainControl: false));
    expect(restored.microphone.microphoneGainPercent, 175);
  });
}
