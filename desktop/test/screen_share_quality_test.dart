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
          expect(
            quality.trackName,
            'screenshare-${resolution}p-${frameRate}fps',
          );
        }
      }
    },
  );

  test(
    'publishes selected profile and allows Android single-layer fallback',
    () {
      for (final resolution in ScreenShareQuality.resolutions) {
        for (final frameRate in ScreenShareQuality.frameRates) {
          final quality = ScreenShareQuality(
            resolution: resolution,
            frameRate: frameRate,
          );
          final androidOptions = quality.publishOptions(simulcast: false);
          final desktopOptions = quality.publishOptions(simulcast: true);

          expect(androidOptions.name, quality.trackName);
          expect(androidOptions.screenShareEncoding?.maxFramerate, frameRate);
          expect(
            androidOptions.screenShareEncoding?.maxBitrate,
            quality.maxBitrate * 1000,
          );
          expect(androidOptions.simulcast, isFalse);
          expect(desktopOptions.simulcast, isTrue);
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

  testWidgets('keeps quality options on one line in Android portrait', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(576, 1280);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScreenShareSetupDialog.show(
                context,
                initialQuality: ScreenShareQuality.balanced,
                allowSourceSelection: false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    for (final label in [
      '720p',
      '1080p',
      '1440p',
      '15 FPS',
      '30 FPS',
      '60 FPS',
    ]) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
    }
    final resolutionLabel = tester.getRect(find.text('Разрешение'));
    final resolutionSegments = tester.getRect(
      find.byKey(const ValueKey('resolution-segments')),
    );
    final frameRateLabel = tester.getRect(find.text('Частота кадров'));
    final frameRateSegments = tester.getRect(
      find.byKey(const ValueKey('frame-rate-segments')),
    );
    expect(resolutionSegments.width, greaterThan(440));
    expect(resolutionLabel.bottom, lessThan(resolutionSegments.top));
    expect(frameRateLabel.bottom, lessThan(frameRateSegments.top));
    expect(tester.takeException(), isNull);
  });
}
