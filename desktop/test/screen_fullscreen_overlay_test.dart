import 'package:boohtacord_desktop/src/screens/screen_fullscreen_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Escape exits the fullscreen screen viewer', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => closed
              ? const Scaffold(body: Text('closed'))
              : ScreenFullscreenOverlay(
                  publisherName: 'Алиса',
                  video: const ColoredBox(color: Colors.black),
                  onClose: () => setState(() => closed = true),
                ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(closed, isTrue);
    expect(find.text('closed'), findsOneWidget);
  });

  testWidgets('fullscreen overlay has an accessible exit control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScreenFullscreenOverlay(
          publisherName: 'Алиса',
          video: const ColoredBox(color: Colors.black),
          onClose: () {},
        ),
      ),
    );

    expect(find.text('Экран Алиса'), findsOneWidget);
    expect(find.byTooltip('Выйти из полноэкранного режима'), findsOneWidget);
  });
}
