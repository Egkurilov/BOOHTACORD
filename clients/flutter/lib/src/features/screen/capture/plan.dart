import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

@immutable
class ScreenShareCapturePlan {
  const ScreenShareCapturePlan({
    required this.requestedParameters,
    required this.requestedMaxFrameRate,
    required this.resolutionLimitSupportedAtCapture,
    required this.frameRateLimitSupportedAtCapture,
  });

  /// Limits sent to the platform; they are not measured output dimensions.
  final VideoParameters requestedParameters;
  final int requestedMaxFrameRate;

  /// API request support; actual output still requires device measurement.
  final bool resolutionLimitSupportedAtCapture;

  /// API evidence only; actual cadence still requires device measurement.
  final bool frameRateLimitSupportedAtCapture;

  factory ScreenShareCapturePlan.forProfile({
    required VideoParameters profileParameters,
    required int profileMaxFrameRate,
    required VideoParameters legacyParameters,
    required int legacyMaxFrameRate,
    required TargetPlatform platform,
  }) {
    final desktop =
        platform == TargetPlatform.windows || platform == TargetPlatform.macOS;
    final macOS = platform == TargetPlatform.macOS;
    return ScreenShareCapturePlan(
      requestedParameters: desktop ? profileParameters : legacyParameters,
      requestedMaxFrameRate: desktop
          ? profileMaxFrameRate
          : legacyMaxFrameRate,
      // macOS consumes width/height before the WebRTC source; Windows only
      // forwards FPS to its native DesktopCapturer start call.
      resolutionLimitSupportedAtCapture: macOS,
      frameRateLimitSupportedAtCapture: desktop,
    );
  }

  /// Static desktop capture options require a new source when a supported
  /// native limit changes. The active publisher must own that restart.
  bool requiresRestartFrom(ScreenShareCapturePlan active) =>
      (frameRateLimitSupportedAtCapture &&
          requestedMaxFrameRate != active.requestedMaxFrameRate) ||
      (resolutionLimitSupportedAtCapture &&
          requestedParameters.dimensions !=
              active.requestedParameters.dimensions);
}
