import 'package:boohtacord_desktop/src/screens/screen_fullscreen_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'mobile downward swipe closes the viewer once (${platform.name})',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        var closes = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: ScreenFullscreenOverlay(
              publisherName: 'Алиса',
              video: const ColoredBox(color: Colors.black),
              onClose: () => closes++,
            ),
          ),
        );
        await tester.dragFrom(const Offset(300, 300), const Offset(0, 120));
        await tester.pump();
        expect(closes, 0);
        await tester.pump(const Duration(milliseconds: 120));
        expect(closes, 0);
        await tester.pumpAndSettle();
        expect(closes, 1);
        await tester.tap(find.byTooltip('Выйти из полноэкранного режима'));
        expect(closes, 1);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

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
