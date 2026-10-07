import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test('desktop plans describe requests and native restart requirements', () {
    const low = ScreenShareQuality(resolution: 720, frameRate: 15);
    const high = ScreenShareQuality(resolution: 1080, frameRate: 60);
    final macLow = low.capturePlan(TargetPlatform.macOS);
    final macHigh = high.capturePlan(TargetPlatform.macOS);
    final windowsLow = low.capturePlan(TargetPlatform.windows);
    final windowsHigh = high.capturePlan(TargetPlatform.windows);

    expect(macLow.requestedMaxFrameRate, 15);
    expect(macLow.requestedParameters.dimensions.height, 720);
    expect(macLow.resolutionLimitSupportedAtCapture, isTrue);
    expect(macLow.frameRateLimitSupportedAtCapture, isTrue);
    expect(macHigh.requiresRestartFrom(macLow), isTrue);
    expect(macHigh.requestedMaxFrameRate, 60);
    expect(macHigh.requestedParameters.dimensions.height, 1080);
    expect(windowsLow.requestedMaxFrameRate, 15);
    expect(windowsLow.requestedParameters.dimensions.height, 720);
    expect(windowsLow.resolutionLimitSupportedAtCapture, isFalse);
    expect(windowsLow.frameRateLimitSupportedAtCapture, isTrue);
    expect(windowsHigh.requiresRestartFrom(windowsLow), isTrue);

    final windows720p30 = ScreenShareQuality(
      resolution: 720,
      frameRate: 30,
    ).capturePlan(TargetPlatform.windows);
    final windows1080p30 = ScreenShareQuality(
      resolution: 1080,
      frameRate: 30,
    ).capturePlan(TargetPlatform.windows);
    final mac1080p30 = ScreenShareQuality(
      resolution: 1080,
      frameRate: 30,
    ).capturePlan(TargetPlatform.macOS);
    final mac720p30 = ScreenShareQuality(
      resolution: 720,
      frameRate: 30,
    ).capturePlan(TargetPlatform.macOS);
    expect(windows720p30.requiresRestartFrom(windows1080p30), isFalse);
    expect(mac1080p30.requiresRestartFrom(mac720p30), isTrue);
  });

  test('mobile keeps its existing source ceiling while desktop plans vary', () {
    const quality = ScreenShareQuality(resolution: 720, frameRate: 15);
    final android = quality.capturePlan(TargetPlatform.android);

    expect(android.requestedMaxFrameRate, 60);
    expect(android.requestedParameters.dimensions.height, 1440);
    expect(android.frameRateLimitSupportedAtCapture, isFalse);
  });

  test('profile scaling keeps odd portrait and ultrawide geometry in bounds', () {
    const quality = ScreenShareQuality(resolution: 720, frameRate: 30);
    const sources = [
      VideoDimensions(1441, 3121),
      VideoDimensions(5121, 1441),
      VideoDimensions(541, 919),
    ];

    for (final source in sources) {
      final scale = quality.scaleResolutionDownBy(source);
      final width = source.width ~/ scale;
      final height = source.height ~/ scale;
      final target = source.height > source.width
          ? const VideoDimensions(720, 1280)
          : const VideoDimensions(1280, 720);

      expect(scale, greaterThanOrEqualTo(1));
      expect(width, lessThanOrEqualTo(source.width));
      expect(height, lessThanOrEqualTo(source.height));
      expect(width, lessThanOrEqualTo(target.width));
      expect(height, lessThanOrEqualTo(target.height));
      expect(width.isEven, isTrue);
      expect(height.isEven, isTrue);
      expect(width / height, closeTo(source.width / source.height, 0.01));
    }
  });
}
