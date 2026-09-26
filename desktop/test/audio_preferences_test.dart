import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('audio preferences persist per account', () async {
    SharedPreferences.setMockInitialValues({});
    final alice = await AudioPreferences.open('alice');
    await AudioPreferences.open('bob');

    await alice.setInputDevice('mic-a');
    await alice.setOutputDevice('speaker-a');
    await alice.setProcessing(
      const AudioProcessingPreferences(
        autoGainControl: false,
        echoCancellation: true,
        noiseSuppression: false,
      ),
    );
    await alice.setActivationMode('PTT');
    await alice.setPttKey(0x100000041, 'A');

    final restoredAlice = await AudioPreferences.open('alice');
    final restoredBob = await AudioPreferences.open('bob');
    expect(restoredAlice.inputDeviceId, 'mic-a');
    expect(restoredAlice.outputDeviceId, 'speaker-a');
    expect(restoredAlice.processing.autoGainControl, isFalse);
    expect(restoredAlice.processing.echoCancellation, isTrue);
    expect(restoredAlice.processing.noiseSuppression, isFalse);
    expect(restoredAlice.activationMode, 'PTT');
    expect(restoredAlice.pttKeyId, 0x100000041);
    expect(restoredAlice.pttKeyLabel, 'A');
    expect(restoredBob.inputDeviceId, isNull);
    expect(restoredBob.processing.autoGainControl, isTrue);
  });
}
