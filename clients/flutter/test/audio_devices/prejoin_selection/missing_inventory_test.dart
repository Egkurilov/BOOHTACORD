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

  test('empty inventory does not pass saved device IDs to Join', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final hardware = Hardware.instance;
    final priorInput = hardware.selectedAudioInput;
    final priorOutput = hardware.selectedAudioOutput;
    const currentInput = MediaDevice(
      'system-mic',
      'Built-in',
      'audioinput',
      null,
    );
    const currentOutput = MediaDevice(
      'system-output',
      'Speakers',
      'audiooutput',
      null,
    );
    hardware.selectedAudioInput = currentInput;
    hardware.selectedAudioOutput = currentOutput;
    addTearDown(() {
      hardware.selectedAudioInput = priorInput;
      hardware.selectedAudioOutput = priorOutput;
    });

    final bootstrap = Completer<void>();
    final bootstrapStarted = Completer<void>();
    final account = const SessionUser(accountId: 'account-a', role: 'MEMBER');
    final harness = VoiceHarness(
      nativeBootstrap: () {
        bootstrapStarted.complete();
        return bootstrap.future;
      },
      account: account,
    );
    addTearDown(harness.dispose);
    final preferences = await AudioPreferences.open(account.accountId);
    await preferences.setInputDevice('missing-mic');
    await preferences.setOutputDevice('missing-output');
    await harness.owner.loadAudioPreferences(account.accountId);
    harness.api.credential.complete(('lease', credential));

    final joining = harness.owner.joinVoice(channel, listenerOnly: true);
    await bootstrapStarted.future;
    bootstrap.complete();
    await harness.room.connectStarted.future;

    expect(harness.owner.selectedAudioInputId, isNull);
    expect(harness.owner.selectedAudioOutputId, isNull);
    expect(harness.owner.audioDeviceWarning, isNotNull);
    expect(hardware.selectedAudioInput?.deviceId, currentInput.deviceId);
    expect(hardware.selectedAudioOutput?.deviceId, currentOutput.deviceId);
    expect(
      harness.createdRoomOptions?.defaultAudioCaptureOptions.deviceId,
      isNull,
    );
    expect(
      harness.createdRoomOptions?.defaultAudioOutputOptions.deviceId,
      isNull,
    );

    harness.room.connecting.complete();
    await joining;
  });
}
