import 'package:boohtacord_desktop/src/services/screen_share_quality.dart';
import 'package:boohtacord_desktop/src/widgets/screen_share_setup_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'maps every resolution and frame-rate combination to capture settings',
    () {
      for (final resolution in ScreenShareQuality.resolutions) {
        for (final frameRate in ScreenShareQuality.frameRates) {
          final quality = ScreenShareQuality(
            resolution: resolution,
            frameRate: frameRate,
          );

          expect(quality.parameters.dimensions.height, resolution);
          expect(quality.parameters.encoding?.maxFramerate, frameRate);
          expect(quality.parameters.encoding!.maxBitrate, greaterThan(0));
        }
      }
    },
  );

  testWidgets('Android setup returns selected resolution and FPS', (
    tester,
  ) async {
    ScreenShareSetupSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await ScreenShareSetupDialog.show(
                  context,
                  initialQuality: ScreenShareQuality.balanced,
                  allowSourceSelection: false,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1440p'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('60 FPS'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-screen-share')));
    await tester.pumpAndSettle();

    expect(result?.sourceId, isNull);
    expect(result?.quality.resolution, 1440);
    expect(result?.quality.frameRate, 60);
  });
}
