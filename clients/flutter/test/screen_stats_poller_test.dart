import 'dart:async';
import 'package:boohtacord_desktop/src/features/screen/metrics/stats_poller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
void main() {
  testWidgets('caller timeout never accumulates native getStats calls', (tester) async {
    final poller = ScreenStatsPoller(), pending = Completer<List<rtc.StatsReport>>();
    var calls = 0;
    Future<List<rtc.StatsReport>> request() { calls++; return pending.future; }
    final first = poller.read(request);
    final firstError = expectLater(first, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 2));
    await firstError;
    final second = poller.read(request);
    final secondError = expectLater(second, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 2));
    await secondError;
    expect(calls, 1);
    pending.complete([]);
    await tester.pump();
    expect(await poller.read(request), isEmpty);
    expect(calls, 1);
    poller.clear();
    expect(await poller.read(request), isEmpty);
    expect(calls, 2);
  });
}
