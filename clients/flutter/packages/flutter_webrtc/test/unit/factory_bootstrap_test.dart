import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('FlutterWebRTC.Method');
  const eventChannel = MethodChannel('FlutterWebRTC.Event');
  const bootstrapEvents = MethodChannel('FlutterWebRTC/peerConnectionEventbootstrap');

  setUp(() {
    WebRTC.initialized = false;
    methodChannel.setMockMethodCallHandler((call) async {
      if (call.method == 'getSources') {
        return {
          'sources': [
            {
              'deviceId': 'default-input',
              'groupId': 'default-group',
              'kind': 'audioinput',
              'label': 'Default microphone',
            },
          ],
        };
      }
      return null;
    });
    eventChannel.setMockMethodCallHandler((_) async => null);
    bootstrapEvents.setMockMethodCallHandler((_) async => null);
  });

  tearDown(() {
    methodChannel.setMockMethodCallHandler(null);
    eventChannel.setMockMethodCallHandler(null);
    bootstrapEvents.setMockMethodCallHandler(null);
  });

  test('initializes once and releases Mac bootstrap before inventory without media', () async {
    final calls = <String>[];
    final initializeStarted = Completer<void>();
    final finishInitialize = Completer<void>();
    methodChannel.setMockMethodCallHandler((call) async {
      calls.add(call.method);
      if (call.method == 'initialize') {
        initializeStarted.complete();
        await finishInitialize.future;
      }
      if (call.method == 'createPeerConnection') {
        expect(call.arguments['configuration']['iceServers'], isEmpty);
        return {'peerConnectionId': 'bootstrap'};
      }
      if (call.method == 'getSources') {
        return {
          'sources': [
            {
              'deviceId': 'default-input',
              'groupId': 'default-group',
              'kind': 'audioinput',
              'label': 'Default microphone',
            },
          ],
        };
      }
      return null;
    });

    final first = ensurePeerConnectionFactoryReady();
    await initializeStarted.future;
    final concurrent = ensurePeerConnectionFactoryReady();
    expect(identical(first, concurrent), isTrue);
    finishInitialize.complete();
    await Future.wait([first, concurrent]);
    await ensurePeerConnectionFactoryReady();

    final devices = await mediaDevices.enumerateDevices();

    expect(devices, hasLength(1));
    expect(devices.single.deviceId, 'default-input');
    expect(calls, Platform.isMacOS ? ['initialize', 'createPeerConnection',
      'peerConnectionClose', 'peerConnectionDispose', 'getSources'] : ['initialize', 'getSources']);
    expect(calls, isNot(contains('getUserMedia')));
    expect(calls, isNot(contains('getDisplayMedia')));
  });
}
