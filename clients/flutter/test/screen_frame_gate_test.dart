import 'package:boohtacord_desktop/src/widgets/screen_frame_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows the web-matching first-frame state until a frame arrives',
    (tester) async {
      VoidCallback? onFirstFrameRendered;

      Widget buildGate(Object generation) => MaterialApp(
        home: SizedBox.expand(
          child: ScreenFrameGate(
            generation: generation,
            builder: (context, onRendered) {
              onFirstFrameRendered = onRendered;
              return const ColoredBox(color: Colors.black);
            },
          ),
        ),
      );

      await tester.pumpWidget(buildGate('track-a'));
      expect(find.text('Получаем первый кадр демонстрации…'), findsOneWidget);
      expect(
        tester.getSize(find.byType(ScreenFrameGate)),
        const Size(800, 600),
      );

      onFirstFrameRendered!();
      await tester.pump();
      expect(find.text('Получаем первый кадр демонстрации…'), findsNothing);

      await tester.pumpWidget(buildGate('track-b'));
      expect(find.text('Получаем первый кадр демонстрации…'), findsOneWidget);
    },
  );

  testWidgets('a stale track frame cannot unlock the replacement track', (
    tester,
  ) async {
    final frameCallbacks = <VoidCallback>[];

    Widget buildGate(Object generation) => MaterialApp(
      home: SizedBox.expand(
        child: ScreenFrameGate(
          generation: generation,
          builder: (context, onRendered) {
            frameCallbacks.add(onRendered);
            return const ColoredBox(color: Colors.black);
          },
        ),
      ),
    );

    await tester.pumpWidget(buildGate('track-a'));
    final oldTrackFrameCallback = frameCallbacks.last;
    await tester.pumpWidget(buildGate('track-b'));
    final currentTrackFrameCallback = frameCallbacks.last;

    oldTrackFrameCallback();
    await tester.pump();
    expect(find.text('Получаем первый кадр демонстрации…'), findsOneWidget);

    currentTrackFrameCallback();
    await tester.pump();
    expect(find.text('Получаем первый кадр демонстрации…'), findsNothing);
  });

  testWidgets('shows a hidden-app explanation instead of a stuck spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: ScreenFrameGate(
            generation: 'local-track',
            waitingMessage: 'Android скрыл выбранное приложение. Вернитесь в него или выберите весь экран.',
            builder: (context, _) => const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );

    expect(
      find.text(
        'Android скрыл выбранное приложение. Вернитесь в него или выберите весь экран.',
      ),
      findsOneWidget,
    );
    expect(find.text('Получаем первый кадр демонстрации…'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
