import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boohtacord_desktop/src/widgets/desktop_window_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows title bar brands the app and controls the window', (
    tester,
  ) async {
    final actions = _FakeDesktopWindowActions();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopWindowChrome(
          platform: TargetPlatform.windows,
          actions: actions,
          child: const Text('Экран приложения'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BOOHTACORD'), findsOneWidget);
    expect(find.text('Экран приложения'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('desktop-window-titlebar'))),
      const Size(1000, 32),
    );
    expect(find.byTooltip('Свернуть'), findsOneWidget);
    expect(find.byTooltip('Развернуть'), findsOneWidget);
    expect(find.byTooltip('Закрыть'), findsOneWidget);

    await tester.tap(find.byTooltip('Свернуть'));
    await tester.tap(find.byTooltip('Развернуть'));
    await tester.pumpAndSettle();
    expect(actions.minimizeCount, 1);
    expect(actions.maximizeCount, 1);
    expect(find.byTooltip('Восстановить'), findsOneWidget);

    await tester.tap(find.byTooltip('Восстановить'));
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.drag(
      find.byKey(const ValueKey('desktop-window-drag-region')),
      const Offset(30, 0),
    );
    await tester.pumpAndSettle();
    expect(actions.restoreCount, 1);
    expect(actions.closeCount, 1);
    expect(actions.dragCount, 1);

    final dragRegion = find.byKey(const ValueKey('desktop-window-drag-region'));
    await tester.tap(dragRegion);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(dragRegion);
    await tester.pumpAndSettle();
    expect(actions.maximizeCount, 2);
    expect(find.byTooltip('Восстановить'), findsOneWidget);
  });

  testWidgets('Windows title bar uses a text-only typographic brand', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 32);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopWindowChrome(
          platform: TargetPlatform.windows,
          actions: _FakeDesktopWindowActions(),
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BOOHTACORD'), findsOneWidget);
    final brand = find.byKey(const ValueKey('desktop-window-brand'));
    expect(brand.hitTestable(), findsOneWidget);
    expect(
      find.descendant(of: brand, matching: find.byType(Icon)),
      findsNothing,
    );
    final wordmark = tester.widget<Text>(
      find.descendant(of: brand, matching: find.text('BOOHTACORD')),
    );
    expect(wordmark.style?.fontFamily, 'Inter');
    expect(wordmark.style?.fontSize, 11);
    expect(wordmark.style?.fontWeight, FontWeight.w800);
    expect(wordmark.style?.letterSpacing, 1.5);
    expect(wordmark.style?.decoration, TextDecoration.none);
  });

  testWidgets('macOS reserves native control space before the brand', (
    tester,
  ) async {
    final actions = _FakeDesktopWindowActions();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopWindowChrome(
          platform: TargetPlatform.macOS,
          actions: actions,
          child: const Text('Экран приложения'),
        ),
      ),
    );

    expect(find.text('BOOHTACORD'), findsOneWidget);
    expect(find.byTooltip('Свернуть'), findsNothing);
    expect(find.byTooltip('Развернуть'), findsNothing);
    expect(find.byTooltip('Закрыть'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('desktop-window-brand'))).dx,
      greaterThanOrEqualTo(72),
    );
  });

  testWidgets('macOS starts native dragging after a mouse pan is recognized', (
    tester,
  ) async {
    final actions = _FakeDesktopWindowActions();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopWindowChrome(
          platform: TargetPlatform.macOS,
          actions: actions,
          child: const SizedBox.shrink(),
        ),
      ),
    );

    final dragRegion = find.byKey(const ValueKey('desktop-window-drag-region'));
    final gesture = await tester.startGesture(
      tester.getCenter(dragRegion),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(actions.dragCount, 0);

    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(actions.dragCount, 1);

    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(actions.dragCount, 1);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('mobile platforms do not get desktop title chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopWindowChrome(
          platform: TargetPlatform.android,
          actions: _FakeDesktopWindowActions(),
          child: const Text('Экран приложения'),
        ),
      ),
    );

    expect(find.text('Экран приложения'), findsOneWidget);
    expect(find.text('BOOHTACORD'), findsNothing);
    expect(find.byKey(const ValueKey('desktop-window-titlebar')), findsNothing);
  });
}

class _FakeDesktopWindowActions implements DesktopWindowActions {
  bool maximized = false;
  int dragCount = 0;
  int minimizeCount = 0;
  int maximizeCount = 0;
  int restoreCount = 0;
  int closeCount = 0;

  @override
  Future<void> close() async => closeCount++;

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  Future<void> maximize() async {
    maximized = true;
    maximizeCount++;
  }

  @override
  Future<void> minimize() async => minimizeCount++;

  @override
  Future<void> restore() async {
    maximized = false;
    restoreCount++;
  }

  @override
  Future<void> startDragging() async => dragCount++;
}
