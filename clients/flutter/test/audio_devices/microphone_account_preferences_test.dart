import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/features/audio/preferences/microphone.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads current account audio preferences before saving sensitivity',
    () async {
      SharedPreferences.setMockInitialValues({});
      final stored = await AudioPreferences.open('signed-in-account');
      await stored.setMicrophoneSettings(
        const MicrophoneSettings(
          vadThresholdDb: -44,
          microphoneGainPercent: 175,
        ),
      );

      final owner = AudioDeviceController(
        readRoom: () => null,
        readAccountId: () => 'signed-in-account',
      );
      addTearDown(owner.dispose);

      await owner.updateMicrophoneSettings(vadThresholdDb: -38);

      expect(owner.audioSettingsError, isNull);
      expect(owner.preferences?.microphone.vadThresholdDb, -38);
      expect(owner.preferences?.microphone.microphoneGainPercent, 175);
      expect(
        (await AudioPreferences.open('signed-in-account'))
            .microphone
            .vadThresholdDb,
        -38,
      );
      expect(
        (await AudioPreferences.open('signed-in-account'))
            .microphone
            .microphoneGainPercent,
        175,
      );
    },
  );
}
