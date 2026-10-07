import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test('keeps default IDs when matching default endpoints exist', () {
    final owner = AudioDeviceController(readRoom: () => null)
      ..audioDeviceScanStatus = AudioDeviceScanStatus.ready
      ..selectedAudioInputId = 'default'
      ..selectedAudioOutputId = 'default';
    addTearDown(owner.dispose);

    owner.applyAudioDevices(const [
      MediaDevice('default', 'System microphone', 'audioinput', null),
      MediaDevice('default', 'System output', 'audiooutput', null),
    ]);

    expect(owner.selectedAudioInputId, 'default');
    expect(owner.selectedAudioOutputId, 'default');
    expect(owner.audioDeviceWarning, isNull);
  });

  test('falls back from unavailable input default and warns after inventory', () {
    final owner = AudioDeviceController(readRoom: () => null)
      ..audioDeviceScanStatus = AudioDeviceScanStatus.ready
      ..selectedAudioInputId = 'default';
    addTearDown(owner.dispose);

    owner.applyAudioDevices(const [
      MediaDevice('built-in-mic', 'Built-in microphone', 'audioinput', null),
    ]);

    expect(owner.selectedAudioInputId, 'built-in-mic');
    expect(
      owner.audioDeviceWarning,
      'Выбранный микрофон отключён. Выберите доступное устройство и проверьте звук.',
    );
  });

  test('falls back from unavailable output default and warns after inventory', () {
    final owner = AudioDeviceController(readRoom: () => null)
      ..audioDeviceScanStatus = AudioDeviceScanStatus.ready
      ..selectedAudioOutputId = 'default';
    addTearDown(owner.dispose);

    owner.applyAudioDevices(const [
      MediaDevice('built-in-speaker', 'Built-in speaker', 'audiooutput', null),
    ]);

    expect(owner.selectedAudioOutputId, 'built-in-speaker');
    expect(
      owner.audioDeviceWarning,
      'Выбранный динамик отключён. Выберите доступное устройство и проверьте звук.',
    );
  });

  test('empty inventory before bootstrap preserves restored account IDs', () {
    final owner = AudioDeviceController(readRoom: () => null)
      ..selectedAudioInputId = 'saved-mic'
      ..selectedAudioOutputId = 'saved-output';
    addTearDown(owner.dispose);

    owner.applyAudioDevices(const []);

    expect(owner.selectedAudioInputId, 'saved-mic');
    expect(owner.selectedAudioOutputId, 'saved-output');
    expect(owner.audioDeviceWarning, isNull);
  });

  test('hotplug does not restore default after the session chose a fallback', () {
    final owner = AudioDeviceController(readRoom: () => null)
      ..audioDeviceScanStatus = AudioDeviceScanStatus.ready
      ..selectedAudioInputId = 'default'
      ..selectedAudioOutputId = 'default';
    addTearDown(owner.dispose);

    owner.applyAudioDevices(const [
      MediaDevice('mic-fallback', 'Built-in microphone', 'audioinput', null),
      MediaDevice('output-fallback', 'Built-in speaker', 'audiooutput', null),
    ]);
    owner.applyAudioDevices(const [
      MediaDevice('default', 'System microphone', 'audioinput', null),
      MediaDevice('mic-fallback', 'Built-in microphone', 'audioinput', null),
      MediaDevice('default', 'System output', 'audiooutput', null),
      MediaDevice('output-fallback', 'Built-in speaker', 'audiooutput', null),
    ]);

    expect(owner.selectedAudioInputId, 'mic-fallback');
    expect(owner.selectedAudioOutputId, 'output-fallback');
  });
}
