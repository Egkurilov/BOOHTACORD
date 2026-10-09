import 'package:boohtacord_desktop/src/widgets/screen_share_setup_dialog.dart';
import 'package:boohtacord_desktop/src/services/screen_share_quality.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.fuchsia,
  ]) {
    testWidgets(
      'pre-picker capability and cancel preserve null selection on $platform',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        ScreenShareSetupSelection? result;
        var closed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('open'),
                  onPressed: () async {
                    result = await ScreenShareSetupDialog.show(
                      context,
                      initialQuality: ScreenShareQuality.balanced,
                      allowSourceSelection: false,
                    );
                    closed = true;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('screen-preflight-capabilities')),
          findsOneWidget,
        );
        expect(find.textContaining('Звук игры не передаётся'), findsOneWidget);
        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('start-screen-share')),
        );
        expect(button.onPressed != null, platform != TargetPlatform.fuchsia);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        expect(closed, isTrue);
        expect(result, isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
  testWidgets('mobile quality choice is preserved in accepted result', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScreenShareSetupDialog(
          initialQuality: ScreenShareQuality.balanced,
          allowSourceSelection: false,
        ),
      ),
    );
    await tester.ensureVisible(find.text('1080p'));
    await tester.tap(find.text('1080p'));
    await tester.pump();
    final button = tester.widget<SegmentedButton<int>>(
      find.descendant(
        of: find.byKey(const ValueKey('resolution-segments')),
        matching: find.byType(SegmentedButton<int>),
      ),
    );
    expect(button.selected, {1080});
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets(
    'setup keeps its actions reachable with the mobile keyboard and 2x text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ScreenShareSetupDialog.show(
                  context,
                  initialQuality: ScreenShareQuality.balanced,
                  allowSourceSelection: false,
                ),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final cancel = find.byTooltip('Закрыть');
      final start = find.byKey(const ValueKey('start-screen-share'));
      await tester.ensureVisible(cancel);
      await tester.ensureVisible(start);
      expect(tester.getRect(start).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(start).bottom, lessThanOrEqualTo(568));
      expect(tester.takeException(), isNull);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
