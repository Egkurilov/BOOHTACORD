import 'package:boohtacord_desktop/src/screens/screen_receiver_diagnostics.dart';
import 'package:boohtacord_desktop/src/screens/screen_packet_loss.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('labels the visible receiver value as ten-second loss', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScreenReceiverDiagnostics(
            track: null,
            isLocal: false,
            hasAudio: false,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();
    expect(find.text('Потери пакетов за 10 с'), findsOneWidget);
  });

  test('formats the recent loss rate as a percentage', () {
    expect(formatScreenPacketLossPercent(null), 'Нет данных');
    expect(formatScreenPacketLossPercent(0), '0 %');
    expect(formatScreenPacketLossPercent(0.5), '0,5 %');
    expect(formatScreenPacketLossPercent(1.25), '1,25 %');
  });

  test('uses recent packets rather than the lifetime loss count', () {
    final window = ScreenPacketLossWindow();
    expect(
      window.add(timestampMs: 0, packetsReceived: 1000, packetsLost: 2476),
      isNull,
    );
    expect(
      window.add(timestampMs: 2000, packetsReceived: 1195, packetsLost: 2481),
      isNull,
    );
    expect(
      window.add(timestampMs: 8000, packetsReceived: 1795, packetsLost: 2481),
      isNull,
    );
    expect(
      window.add(timestampMs: 10000, packetsReceived: 1995, packetsLost: 2481),
      0.5,
    );
    expect(
      window.add(timestampMs: 12000, packetsReceived: 2195, packetsLost: 2481),
      0,
    );
  });

  test('resets on counter rollover, missing stats, and long gaps', () {
    final window = ScreenPacketLossWindow();
    expect(
      window.add(timestampMs: 0, packetsReceived: 100, packetsLost: 1),
      isNull,
    );
    expect(
      window.add(timestampMs: 10000, packetsReceived: 100, packetsLost: 1),
      isNull,
    );
    expect(
      window.add(timestampMs: 12000, packetsReceived: 1, packetsLost: 0),
      isNull,
    );
    expect(
      window.add(timestampMs: 22000, packetsReceived: 91, packetsLost: 10),
      10,
    );
    expect(
      window.add(timestampMs: 40000, packetsReceived: 100, packetsLost: 11),
      isNull,
    );
    expect(
      window.add(timestampMs: 50000, packetsReceived: 200, packetsLost: 20),
      8.26,
    );
    expect(
      window.add(timestampMs: 52000, packetsReceived: null, packetsLost: 21),
      isNull,
    );
  });
}
