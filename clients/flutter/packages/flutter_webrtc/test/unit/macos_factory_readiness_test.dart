import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_webrtc/src/native/factory_bootstrap/readiness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('FlutterWebRTC.Method');
  const events = MethodChannel('FlutterWebRTC/peerConnectionEventbootstrap');
  late List<String> calls;
  var ready = false, failCreate = false, failClose = false;
  setUp(() {
    WebRTC.initialized = false; calls = []; ready = failCreate = failClose = false;
    methods.setMockMethodCallHandler((call) async {
      calls.add(call.method);
      if (call.method == 'createPeerConnection') {
        if (failCreate) throw PlatformException(code: 'fixture');
        expect(call.arguments['configuration']['iceServers'], isEmpty);
        ready = true; return {'peerConnectionId': 'bootstrap'};
      }
      if (call.method == 'peerConnectionClose' && failClose) {
        throw PlatformException(code: 'fixture');
      }
      if (call.method == 'getSources') {
        return {'sources': [
        {'deviceId': ready ? 'physical-fixture' : 'default', 'groupId': 'fixture', 'kind': 'audioinput', 'label': 'Fixture'},
        ]};
      }
      return null;
    });
    events.setMockMethodCallHandler((call) async { calls.add('event:${call.method}'); return null; });
  });
  tearDown(() { methods.setMockMethodCallHandler(null); events.setMockMethodCallHandler(null); });
  test('initialize alone remains lazy; ready awaits creation, close and event disposal before inventory', () async {
    await WebRTC.initialize();
    expect((await mediaDevices.enumerateDevices()).single.deviceId, 'default');
    final bootstrap = FactoryReadiness(isMacOS: () => true);
    final first = bootstrap.ensure(), concurrent = bootstrap.ensure();
    expect(identical(first, concurrent), isTrue);
    await first; await bootstrap.ensure();
    expect((await mediaDevices.enumerateDevices()).single.deviceId, 'physical-fixture');
    expect(calls.where((call) => call == 'createPeerConnection'), hasLength(1));
    expect(calls.indexOf('peerConnectionClose'), lessThan(calls.indexOf('peerConnectionDispose')));
    expect(calls.indexOf('event:cancel'), lessThan(calls.indexOf('peerConnectionDispose')));
    expect(calls.where((call) => ['getUserMedia', 'getDisplayMedia', 'createOffer', 'setLocalDescription', 'setRemoteDescription', 'addTrack'].contains(call)), isEmpty);
  });
  test('creation failure is retriable without accepting readiness', () async {
    final bootstrap = FactoryReadiness(isMacOS: () => true); failCreate = true;
    await expectLater(bootstrap.ensure(), throwsA(anything));
    failCreate = false; await bootstrap.ensure();
    expect(calls.where((call) => call == 'createPeerConnection'), hasLength(2));
  });
  test('close failure still cancels events and disposes; retry remains possible', () async {
    final bootstrap = FactoryReadiness(isMacOS: () => true); failClose = true;
    await expectLater(bootstrap.ensure(), throwsA(anything));
    expect(calls, contains('peerConnectionDispose')); expect(calls, contains('event:cancel'));
    failClose = false; await bootstrap.ensure();
    expect(calls.where((call) => call == 'createPeerConnection'), hasLength(2));
  });
  test('other native platforms only initialize', () async {
    await FactoryReadiness(isMacOS: () => false).ensure();
    expect(calls, ['initialize']);
  });
}
