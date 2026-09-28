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
    'enumerates named Android USB inputs and communication outputs',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'enumerateUsb');
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
              {'deviceId': 43, 'kind': 'audiooutput', 'label': 'malformed'},
            ];
          });

      final devices = await AndroidAudioDevices.enumerateAdditionalDevices();

      expect(devices, hasLength(2));
      expect(devices[0].deviceId, '41');
      expect(devices[0].kind, 'audioinput');
      expect(devices[0].label, 'USB Microphone');
      expect(devices[1].deviceId, 'android-usb-route:42');
      expect(devices[1].kind, 'audiooutput');
      expect(AndroidAudioDevices.isUsbOutput(devices[1].deviceId), isTrue);
    },
  );

  test('uses native Android route only for USB outputs', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'selectUsbOutput' ? true : null;
        });

    expect(
      await AndroidAudioDevices.selectUsbOutput('android-usb-route:42'),
      isTrue,
    );
    expect(AndroidAudioDevices.isUsbOutput('bluetooth'), isFalse);
    await AndroidAudioDevices.clearUsbOutput();

    expect(calls.map((call) => call.method), [
      'selectUsbOutput',
      'clearUsbOutput',
    ]);
    expect(calls.first.arguments, {'deviceId': '42'});
  });

  test('does not invoke Android routing on desktop', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          fail('Unexpected native call ${call.method}');
        });

    expect(await AndroidAudioDevices.enumerateAdditionalDevices(), isEmpty);
    expect(
      await AndroidAudioDevices.selectUsbOutput('android-usb-route:42'),
      isFalse,
    );
    await AndroidAudioDevices.clearUsbOutput();
  });
}
