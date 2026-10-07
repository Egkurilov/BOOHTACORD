import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ready empty inventory clears a stale microphone to system fallback', () {
    final owner = AudioDeviceController(readRoom: () => null)
      ..audioDeviceScanStatus = AudioDeviceScanStatus.ready
      ..selectedAudioInputId = 'disconnected-mic';
    addTearDown(owner.dispose);
    owner.applyAudioDevices(const [
      MediaDevice('available-speaker', 'Speakers', 'audiooutput', null),
    ]);

    expect(owner.selectedAudioInputId, isNull);
    expect(
      owner.audioDeviceWarning,
      'Выбранный микрофон отключён. Выберите доступное устройство и проверьте звук.',
    );
  });

  test('ready empty inventory clears a stale output to system fallback', () {
    final owner = AudioDeviceController(readRoom: () => null)
      ..audioDeviceScanStatus = AudioDeviceScanStatus.ready
      ..selectedAudioOutputId = 'disconnected-output';
    addTearDown(owner.dispose);
    owner.applyAudioDevices(const [
      MediaDevice('available-mic', 'Microphone', 'audioinput', null),
    ]);

    expect(owner.selectedAudioOutputId, isNull);
    expect(
      owner.audioDeviceWarning,
      'Выбранный динамик отключён. Выберите доступное устройство и проверьте звук.',
    );
  });
}
