import 'package:boohtacord_desktop/src/services/android_audio_devices.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('boohtacord/audio_devices');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'enumerates Android USB inputs and system communication outputs',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'enumerateAudioDevices');
            return [
              {
                'deviceId': '41',
                'kind': 'audioinput',
                'label': 'USB Microphone',
                'groupId': 'usb:41',
              },
              {
                'deviceId': 'android-usb-route:42',
                'kind': 'audiooutput',
                'label': 'USB Headset',
                'groupId': 'usb:42',
              },
              {
                'deviceId': 'android-communication-route:44',
                'kind': 'audiooutput',
                'label': 'Динамик телефона',
                'groupId': 'android:44',
              },
              {
                'deviceId': 'android-communication-route:45',
                'kind': 'audiooutput',
                'label': 'Bluetooth headset',
                'groupId': 'android:45',
              },
              {'deviceId': 43, 'kind': 'audiooutput', 'label': 'malformed'},
            ];
          });

      final devices = await AndroidAudioDevices.enumerateAdditionalDevices();

      expect(devices, hasLength(4));
      expect(devices[0].deviceId, '41');
      expect(devices[0].kind, 'audioinput');
      expect(devices[0].label, 'USB Microphone');
      expect(devices[1].deviceId, 'android-usb-route:42');
      expect(devices[1].kind, 'audiooutput');
      expect(AndroidAudioDevices.isUsbOutput(devices[1].deviceId), isTrue);
      expect(devices[2].deviceId, 'android-communication-route:44');
      expect(devices[2].label, 'Динамик телефона');
      expect(
        AndroidAudioDevices.isNativeOutputRoute(devices[2].deviceId),
        isTrue,
      );
      expect(AndroidAudioDevices.isNativeOutputRoute('bluetooth'), isFalse);
    },
  );

  test('selects native Android communication output routes', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'selectCommunicationOutput' ? true : null;
        });

    expect(
      await AndroidAudioDevices.selectNativeOutput('android-usb-route:42'),
      isTrue,
    );
    expect(
      await AndroidAudioDevices.selectNativeOutput(
        'android-communication-route:44',
      ),
      isTrue,
    );
    expect(AndroidAudioDevices.isNativeOutputRoute('bluetooth'), isFalse);
    await AndroidAudioDevices.clearNativeOutput();

    expect(calls.map((call) => call.method), [
      'selectCommunicationOutput',
      'selectCommunicationOutput',
      'clearCommunicationOutput',
    ]);
    expect(calls.first.arguments, {'deviceId': '42'});
    expect(calls[1].arguments, {'deviceId': '44'});
  });

  test('does not invoke Android routing on desktop', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          fail('Unexpected native call ${call.method}');
        });

    expect(await AndroidAudioDevices.enumerateAdditionalDevices(), isEmpty);
    expect(
      await AndroidAudioDevices.selectNativeOutput('android-usb-route:42'),
      isFalse,
    );
    await AndroidAudioDevices.clearNativeOutput();
  });
}
