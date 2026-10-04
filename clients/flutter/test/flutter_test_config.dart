import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const webrtcMethodChannel = MethodChannel('FlutterWebRTC.Method');

  // Native audio hooks are unavailable in widget tests. Reply immediately so
  // bounded production timeouts do not leave FakeAsync timers pending.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(webrtcMethodChannel, (call) async {
          if (call.method == 'initialize') return null;
          if (call.method == 'getSources') return {'sources': <Object>[]};
          if (call.method == 'setMicrophoneControls' ||
              call.method == 'getMicrophoneControlsState') {
            return {'status': 'unsupported'};
          }
          throw MissingPluginException('No test handler for ${call.method}');
        });
  });

  await testMain();
}
