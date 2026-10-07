import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('FlutterWebRTC.Method');
  const peerConnectionId = 'factory-bootstrap-test';
  const eventChannel = MethodChannel(
    'FlutterWebRTC/peerConnectionEvent$peerConnectionId',
  );

  setUp(() {
    WebRTC.initialized = false;
    methodChannel.setMockMethodCallHandler((call) async {
      if (call.method == 'createPeerConnection') {
        return {'peerConnectionId': peerConnectionId};
      }
      return null;
    });
    eventChannel.setMockMethodCallHandler((_) async => null);
  });

  tearDown(() {
    methodChannel.setMockMethodCallHandler(null);
    eventChannel.setMockMethodCallHandler(null);
  });

  test('warms the factory and disposes the transient peer connection',
      () async {
    final calls = <String>[];
    methodChannel.setMockMethodCallHandler((call) async {
      calls.add(call.method);
      if (call.method == 'createPeerConnection') {
        return {'peerConnectionId': peerConnectionId};
      }
      return null;
    });
    eventChannel.setMockMethodCallHandler((call) async {
      calls.add('event:${call.method}');
      return null;
    });

    await ensurePeerConnectionFactoryReady();
    await ensurePeerConnectionFactoryReady();

    expect(calls, contains('initialize'));
    expect(calls, contains('createPeerConnection'));
    expect(calls, contains('event:listen'));
    expect(calls, contains('event:cancel'));
    expect(calls, contains('peerConnectionDispose'));
    expect(
      calls.indexOf('initialize'),
      lessThan(calls.indexOf('createPeerConnection')),
    );
    expect(
      calls.indexOf('event:cancel'),
      lessThan(calls.indexOf('peerConnectionDispose')),
    );
    expect(
      calls.where((call) => call == 'createPeerConnection'),
      hasLength(1),
    );
    expect(
      calls.where(
        (call) => !{
          'initialize',
          'createPeerConnection',
          'event:listen',
          'event:cancel',
          'peerConnectionDispose',
        }.contains(call),
      ),
      isEmpty,
    );
  });
}
