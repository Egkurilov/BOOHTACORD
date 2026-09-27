import 'package:boohtacord_desktop/src/screens/screen_receiver_diagnostics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('computes receiver rates from counters and elapsed time', () {
    const previous = ScreenReceiverSnapshot(
      timestampMs: 1000,
      bytesReceived: 100000,
      framesDecoded: 20,
      framesDropped: 1,
      packetsLost: 2,
    );
    const current = ScreenReceiverSnapshot(
      timestampMs: 3000,
      bytesReceived: 1100000,
      framesDecoded: 140,
      framesDropped: 4,
      jitterSeconds: 0.012,
      packetsLost: 3,
      frameWidth: 1920,
      frameHeight: 1080,
      framesPerSecond: 30,
    );

    final metrics = compareScreenReceiverStats(previous, current);

    expect(metrics.bitrateKbps, 4000);
    expect(metrics.decodedFps, 60);
    expect(metrics.droppedFrames, 3);
    expect(metrics.jitterMs, 12);
    expect(metrics.packetsLost, 3);
  });

  test('does not invent rates without a valid baseline', () {
    const current = ScreenReceiverSnapshot(
      timestampMs: 2000,
      framesDecoded: 120,
      framesDropped: 4,
      bytesReceived: 50000,
      jitterSeconds: double.nan,
      packetsLost: -1,
    );

    final metrics = compareScreenReceiverStats(null, current);

    expect(metrics.bitrateKbps, isNull);
    expect(metrics.decodedFps, isNull);
    expect(metrics.droppedFrames, isNull);
    expect(metrics.jitterMs, isNull);
    expect(metrics.packetsLost, isNull);
  });

  testWidgets('reports missing receiver stats and local no-audio preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScreenReceiverDiagnostics(
            track: null,
            isLocal: true,
            hasAudio: false,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Нет свежих данных'), findsNWidgets(2));
    expect(find.text('Предпросмотр без звука'), findsOneWidget);
    expect(find.text('Нет данных от приёмника'), findsOneWidget);
  });
}
