import 'package:boohtacord_desktop/src/services/screen_share_quality.dart';
import 'package:boohtacord_desktop/src/widgets/screen_share_setup_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

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

  test('resolution profile scales source without cropping or upscaling', () {
    for (final resolution in ScreenShareQuality.resolutions) {
      final quality = ScreenShareQuality(resolution: resolution, frameRate: 30);
      final source = const VideoDimensions(3840, 2160);
      final scale = quality.scaleResolutionDownBy(source);
      final encoding = quality
          .publishOptions(simulcast: false, sourceDimensions: source)
          .screenShareEncoding!;
      final encodedWidth = source.width ~/ scale;
      final encodedHeight = source.height ~/ scale;

      expect(encoding.scaleResolutionDownBy, scale);
      expect(scale, greaterThanOrEqualTo(1));
      expect(
        encodedWidth,
        lessThanOrEqualTo(quality.parameters.dimensions.width),
      );
      expect(
        encodedHeight,
        lessThanOrEqualTo(quality.parameters.dimensions.height),
      );
      expect(encodedWidth.isEven, isTrue);
      expect(encodedHeight.isEven, isTrue);
    }

    final portraitSource = const VideoDimensions(1440, 3120);
    final portrait720 = const ScreenShareQuality(
      resolution: 720,
      frameRate: 30,
    );
    final portraitScale = portrait720.scaleResolutionDownBy(portraitSource);
    expect(
      portraitSource.width ~/ portraitScale,
      lessThan(portraitSource.width),
    );
    expect(portraitSource.height ~/ portraitScale, lessThanOrEqualTo(1280));
    expect(
      const ScreenShareQuality(
        resolution: 1080,
        frameRate: 30,
      ).scaleResolutionDownBy(const VideoDimensions(540, 1170)),
      1,
    );
  });

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

  testWidgets('iOS setup explains app-only capture before starting', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
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
    expect(find.textContaining('только содержимое BOOHTACORD'), findsOneWidget);
    expect(find.text('Весь экран'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('start-screen-share')));
    await tester.pumpAndSettle();
    expect(result?.quality, ScreenShareQuality.balanced);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('keeps quality options on one line in Android portrait', (
    tester,
  ) async {
    // 576 physical pixels at a typical Android density is a 360 logical-pixel
    // viewport, matching the narrow phone layout rather than a tablet-sized
    // 576 logical-pixel canvas.
    tester.view.devicePixelRatio = 1.6;
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
    expect(resolutionSegments.width, greaterThan(230));
    expect(resolutionSegments.width, lessThan(300));
    expect(resolutionLabel.bottom, lessThan(resolutionSegments.top));
    expect(frameRateLabel.bottom, lessThan(frameRateSegments.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps Android picker usable at the minimum 320 dp width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
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

    final start = tester.getRect(
      find.byKey(const ValueKey('start-screen-share')),
    );
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
    expect(start.bottom, lessThanOrEqualTo(640));
    await tester.ensureVisible(
      find.byKey(const ValueKey('resolution-segments')),
    );
    await tester.pumpAndSettle();
    final visibleResolution = tester.getRect(
      find.byKey(const ValueKey('resolution-segments')),
    );
    expect(visibleResolution.top, greaterThanOrEqualTo(0));
    expect(visibleResolution.bottom, lessThanOrEqualTo(640));

    await tester.ensureVisible(
      find.byKey(const ValueKey('frame-rate-segments')),
    );
    await tester.pumpAndSettle();
    final visibleFrameRate = tester.getRect(
      find.byKey(const ValueKey('frame-rate-segments')),
    );
    expect(visibleFrameRate.top, greaterThanOrEqualTo(0));
    expect(visibleFrameRate.bottom, lessThanOrEqualTo(640));
    expect(
      tester.getRect(find.byKey(const ValueKey('start-screen-share'))).bottom,
      lessThanOrEqualTo(640),
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('start-screen-share')),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
