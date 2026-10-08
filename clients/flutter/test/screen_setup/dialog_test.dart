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
}
