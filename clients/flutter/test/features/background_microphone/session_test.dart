import 'dart:async';
import 'package:boohtacord_desktop/src/features/voice/background_microphone/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non Android does not start any native service', () async {
    var calls = 0;
    final session = MicrophoneForegroundSession(android: false, invoke: (_) async { calls++; return true; });
    expect(await session.canStart(), true); expect(await session.start(), true);
    await session.stop(); await session.dispose(); expect(calls, 0);
  });
  test('native promotion failure does not claim active background microphone', () async {
    final calls = <String>[];
    final session = MicrophoneForegroundSession(android: true, invoke: (method) async { calls.add(method); return false; });
    expect(await session.canStart(), false); expect(await session.start(), false);
    expect(session.active, false); await session.stop(); expect(calls, contains('stop'));
  });
  test('stop invalidates late start results without restarting service', () async {
    final ready = Completer<bool>(); final calls = <String>[];
    final session = MicrophoneForegroundSession(android: true, invoke: (method) {
      calls.add(method); return method == 'start' ? ready.future : Future.value(true);
    });
    final starting = session.start(); await session.stop(); ready.complete(true);
    expect(await starting, false); expect(session.active, false); expect(calls, ['start', 'stop']);
  });
  test('dispose prevents new capture intent and clears native service', () async {
    final calls = <String>[];
    final session = MicrophoneForegroundSession(android: true, invoke: (method) async { calls.add(method); return true; });
    expect(await session.start(), true); await session.dispose();
    expect(await session.canStart(), false); expect(await session.start(), false);
    expect(calls, ['start', 'stop']);
  });
}
