import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/admission/audio.dart';
import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../voice_scope/api.dart';

class _Fixture {
  _Fixture(this.account);
  final SessionUser account;
  final scope = SessionScope();
  final api = DelayedVoiceApi();
  late final AudioDeviceController audio = AudioDeviceController(
    readRoom: () => owner.room,
  );
  late final screen = ScreenShareController(
    api,
    scope,
    readRoom: () => owner.room,
    voiceReady: () => true,
  );
  late final VoiceController owner = VoiceController(
    api,
    scope,
    audio,
    screen,
    readUser: () => account,
    reportError: (_) {},
    formatError: (cause) => cause.toString(),
  );

  void dispose() {
    owner.dispose();
    screen.dispose();
    audio.dispose();
  }
}

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

  test('prejoin picks persist per account through room options and reload', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final hardware = Hardware.instance;
    final previousInput = hardware.selectedAudioInput;
    final previousOutput = hardware.selectedAudioOutput;
    addTearDown(() {
      hardware.selectedAudioInput = previousInput;
      hardware.selectedAudioOutput = previousOutput;
    });
    const account = SessionUser(accountId: 'account-a', role: 'MEMBER');
    final first = _Fixture(account);
    addTearDown(first.dispose);
    await first.owner.loadAudioPreferences(account.accountId);
    first.audio.applyAudioDevices(const [
      MediaDevice('mic-default', 'Default mic', 'audioinput', null),
      MediaDevice('mic-selected', 'USB mic', 'audioinput', null),
      MediaDevice('speaker-default', 'Default output', 'audiooutput', null),
      MediaDevice('speaker-selected', 'USB output', 'audiooutput', null),
    ]);
    await first.audio.selectAudioInput('mic-selected');
    await first.audio.selectAudioOutput('speaker-selected');

    expect(hardware.selectedAudioInput?.deviceId, 'mic-selected');
    expect(hardware.selectedAudioOutput?.deviceId, 'speaker-selected');
    expect(first.audio.captureOptions.deviceId, 'mic-selected');
    final options = first.owner.voiceRoomOptions();
    expect(options.defaultAudioCaptureOptions.deviceId, 'mic-selected');
    expect(options.defaultAudioOutputOptions.deviceId, 'speaker-selected');
    expect((await AudioPreferences.open('account-a')).inputDeviceId, 'mic-selected');
    expect((await AudioPreferences.open('account-a')).outputDeviceId, 'speaker-selected');
    expect((await AudioPreferences.open('account-b')).inputDeviceId, isNull);
    expect((await AudioPreferences.open('account-b')).outputDeviceId, isNull);

    final restarted = _Fixture(account);
    addTearDown(restarted.dispose);
    await restarted.owner.loadAudioPreferences(account.accountId);
    restarted.audio.applyAudioDevices(const [
      MediaDevice('mic-selected', 'USB mic', 'audioinput', null),
      MediaDevice('speaker-selected', 'USB output', 'audiooutput', null),
    ]);
    expect(restarted.audio.selectedAudioInputId, 'mic-selected');
    expect(restarted.audio.selectedAudioOutputId, 'speaker-selected');
    expect(restarted.owner.voiceRoomOptions().defaultAudioCaptureOptions.deviceId,
        'mic-selected');
    expect(restarted.owner.voiceRoomOptions().defaultAudioOutputOptions.deviceId,
        'speaker-selected');
  });
}
