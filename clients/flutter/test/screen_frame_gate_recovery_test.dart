import 'package:boohtacord_desktop/src/widgets/screen_frame_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offers an explicit retry after bounded recovery is exhausted', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenFrameGate(
            generation: 'screen-1',
            recoveryExhausted: true,
            onRecoveryRetry: () => retries++,
            builder: (context, onFirstFrameRendered) =>
                const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );

    final retry = find.text('Повторить просмотр');
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    expect(retries, 1);
  });

  testWidgets('does not show a manual retry before automatic recovery ends', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenFrameGate(
            generation: 'screen-1',
            onRecoveryRetry: () {},
            builder: (context, onFirstFrameRendered) =>
                const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );

    expect(find.text('Повторить просмотр'), findsNothing);
  });
}
