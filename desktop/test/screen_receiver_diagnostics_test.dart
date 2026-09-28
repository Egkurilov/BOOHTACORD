import 'package:boohtacord_desktop/src/screens/screen_receiver_diagnostics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    expect(
      find.byTooltip('Метрики приёмника не применимы к предпросмотру'),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.text('Профиль источника')).style?.fontSize,
      12,
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Предпросмотр без звука'), findsOneWidget);
    expect(find.text('Нет данных от приёмника'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Предпросмотр без звука'), findsNothing);

    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(500, 100));
    await tester.pumpAndSettle();
    expect(find.text('Предпросмотр без звука'), findsNothing);
  });

  testWidgets('shows the source profile transmitted in the track name', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScreenReceiverDiagnostics(
            track: null,
            isLocal: false,
            hasAudio: false,
            sourceTrackName: 'screenshare-1440p-60fps',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();
    expect(find.text('1440p · 60 FPS'), findsOneWidget);
  });

  testWidgets('keeps the diagnostics popover within a compact viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: ScreenReceiverDiagnostics(
              track: null,
              isLocal: false,
              hasAudio: false,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();

    expect(find.text('Нет данных от приёмника'), findsOneWidget);
    final panelRect = tester.getRect(
      find.byKey(const ValueKey('screen-receiver-diagnostics-popover')),
    );
    expect(panelRect.width, 288);
    expect(panelRect.left, greaterThanOrEqualTo(0));
    expect(panelRect.right, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
  });
}
