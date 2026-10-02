import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';

class PendingPreferences extends AudioPreferences {
  PendingPreferences() : super(null, 'old-account');
  final write = Completer<void>();
  @override
  Future<void> setProcessing(AudioProcessingPreferences value) => write.future;
}

void main() {
  test(
    'an old preference failure cannot reset a replacement account',
    () async {
      final old = PendingPreferences();
      final owner = AudioDeviceController(readRoom: () => null)
        ..preferences = old;
      addTearDown(owner.dispose);
      final operation = owner.setAudioProcessing(
        const AudioProcessingPreferences(autoGainControl: false),
      );
      owner.preferences = AudioPreferences(null, 'new-account');
      const current = AudioProcessingPreferences(noiseSuppression: false);
      owner.audioProcessing = current;
      old.write.completeError(StateError('old write failed'));
      await operation;
      expect(owner.audioProcessing, same(current));
      expect(owner.audioSettingsError, isNull);
    },
  );
}
