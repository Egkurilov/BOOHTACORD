import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methodChannel = MethodChannel('FlutterWebRTC.Method');
  const eventChannel = EventChannel('FlutterWebRTC.Event');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(methodChannel, (_) async => null);
    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(onListen: (_, __) {}),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(eventChannel, null);
  });

  test('Hardware construction does not independently enumerate devices', () async {
    var sourceCalls = 0;
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'getSources') {
        sourceCalls++;
        return {'sources': <Object>[]};
      }
      return null;
    });

    final hardware = Hardware.instance;
    await Future<void>.delayed(Duration.zero);

    expect(sourceCalls, 0);
    await hardware.enumerateDevices();
    expect(sourceCalls, 1);
  });

  test('device-change bursts coalesce while one inventory scan is pending', () async {
    final finishFirstScan = Completer<void>();
    var sourceCalls = 0;
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'getSources') {
        sourceCalls++;
        if (sourceCalls == 1) await finishFirstScan.future;
        return {'sources': <Object>[]};
      }
      return null;
    });

    final hardware = Hardware.instance;
    expect(hardware.onDeviceChange.isClosed, isFalse);
    rtc.navigator.mediaDevices.ondevicechange?.call(null);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(sourceCalls, 1);

    rtc.navigator.mediaDevices.ondevicechange?.call(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    rtc.navigator.mediaDevices.ondevicechange?.call(null);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(sourceCalls, 1);

    finishFirstScan.complete();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(sourceCalls, 2);
  });
}
