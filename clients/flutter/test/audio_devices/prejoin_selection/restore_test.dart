import 'dart:async';

import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../voice_scope/api.dart';
import '../voice_scope/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(
      const MethodChannel('FlutterWebRTC.Method'),
      (_) async => null,
    );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(
      const MethodChannel('FlutterWebRTC.Method'),
      null,
    );
  });

  test(
    'restored devices apply after inventory and before room creation',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final hardware = Hardware.instance;
      final priorInput = hardware.selectedAudioInput;
      final priorOutput = hardware.selectedAudioOutput;
      addTearDown(() {
        hardware.selectedAudioInput = priorInput;
        hardware.selectedAudioOutput = priorOutput;
      });
      const fallbackInput = MediaDevice(
        'default-mic',
        'Built-in mic',
        'audioinput',
        null,
      );
      const fallbackOutput = MediaDevice(
        'default-output',
        'Speakers',
        'audiooutput',
        null,
      );
      const savedInput = MediaDevice('usb-mic', 'USB mic', 'audioinput', null);
      const savedOutput = MediaDevice(
        'usb-output',
        'USB output',
        'audiooutput',
        null,
      );
      hardware.selectedAudioInput = fallbackInput;
      hardware.selectedAudioOutput = fallbackOutput;
      final bootstrap = Completer<void>();
      final bootstrapStarted = Completer<void>();
      const account = SessionUser(accountId: 'account-a', role: 'MEMBER');
      final harness = VoiceHarness(
        nativeBootstrap: () {
          bootstrapStarted.complete();
          return bootstrap.future;
        },
        account: account,
      )
        ..enumeratedDevices = const [
          fallbackInput,
          savedInput,
          fallbackOutput,
          savedOutput,
        ];
      addTearDown(harness.dispose);
      final preferences = await AudioPreferences.open('account-a');
      await preferences.setInputDevice(savedInput.deviceId);
      await preferences.setOutputDevice(savedOutput.deviceId);
      await harness.owner.loadAudioPreferences(account.accountId);

      harness.api.credential.complete(('lease', credential));
      final joining = harness.owner.joinVoice(channel, listenerOnly: true);
      await bootstrapStarted.future;
      expect(harness.created, 0);
      expect(hardware.selectedAudioInput?.deviceId, fallbackInput.deviceId);
      expect(hardware.selectedAudioOutput?.deviceId, fallbackOutput.deviceId);

      bootstrap.complete();
      await harness.room.connectStarted.future;
      expect(harness.room.connectCalled, isTrue);
      expect(hardware.selectedAudioInput?.deviceId, savedInput.deviceId);
      expect(hardware.selectedAudioOutput?.deviceId, savedOutput.deviceId);
      expect(
        harness.createdRoomOptions?.defaultAudioCaptureOptions.deviceId,
        savedInput.deviceId,
      );
      expect(
        harness.createdRoomOptions?.defaultAudioOutputOptions.deviceId,
        savedOutput.deviceId,
      );
      harness.room.connecting.complete();
      await joining;
    },
  );
}
