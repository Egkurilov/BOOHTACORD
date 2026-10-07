import 'package:boohtacord_desktop/src/widgets/screen_video_renderer_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('stale fullscreen renderer is gone during route exit', (
    tester,
  ) async {
    final lease = ScreenFullscreenRendererLease();
    addTearDown(lease.dispose);
    final dialogContext = await _openFullscreenRoute(tester, lease);
    expect(find.byKey(const ValueKey('fullscreen-renderer')), findsOneWidget);

    var popped = false;
    lease.expire(() {
      expect(lease.active, isFalse);
      popped = true;
      Navigator.of(dialogContext).pop();
    });
    expect(popped, isTrue);

    await tester.pump();
    expect(find.byKey(const ValueKey('fullscreen-renderer')), findsNothing);
    expect(find.text('fullscreen route remains'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey('fullscreen-renderer')), findsNothing);
    expect(find.text('fullscreen route remains'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('fullscreen route remains'), findsNothing);
  });

  testWidgets('normal user close keeps renderer through exit animation', (
    tester,
  ) async {
    final lease = ScreenFullscreenRendererLease();
    addTearDown(lease.dispose);
    final dialogContext = await _openFullscreenRoute(tester, lease);

    Navigator.of(dialogContext).pop();
    await tester.pump();
    expect(find.byKey(const ValueKey('fullscreen-renderer')), findsOneWidget);
    expect(find.text('fullscreen route remains'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fullscreen-renderer')), findsNothing);
  });
}

Future<BuildContext> _openFullscreenRoute(
  WidgetTester tester,
  ScreenFullscreenRendererLease lease,
) async {
  late BuildContext dialogContext;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showGeneralDialog<void>(
            context: context,
            transitionDuration: const Duration(milliseconds: 160),
            transitionBuilder: (_, animation, _, child) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            pageBuilder: (context, _, _) {
              dialogContext = context;
              return Stack(
                children: [
                  const Center(child: Text('fullscreen route remains')),
                  ScreenFullscreenRendererGate(
                    lease: lease,
                    child: const ColoredBox(
                      key: ValueKey('fullscreen-renderer'),
                      color: Colors.white,
                    ),
                  ),
                ],
              );
            },
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return dialogContext;
}
