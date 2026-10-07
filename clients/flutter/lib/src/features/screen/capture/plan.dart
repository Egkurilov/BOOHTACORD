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

  /// Source-option support; actual output still requires device measurement.
  final bool resolutionLimitSupportedAtCapture;

  /// Platform frame gate support; actual cadence still requires measurement.
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
    final android = platform == TargetPlatform.android;
    final macOS = platform == TargetPlatform.macOS;
    return ScreenShareCapturePlan(
      requestedParameters: desktop || android
          ? profileParameters
          : legacyParameters,
      requestedMaxFrameRate: desktop || android
          ? profileMaxFrameRate
          : legacyMaxFrameRate,
      // Android caps MediaProjection output and gates frames before WebRTC's
      // video source. macOS applies dimensions natively; Windows forwards FPS
      // to DesktopCapturer. iOS keeps its legacy capture path.
      resolutionLimitSupportedAtCapture: macOS || android,
      frameRateLimitSupportedAtCapture: desktop || android,
    );
  }

  /// Static desktop and Android source options require a new source when a
  /// supported limit changes. The active publisher must own that restart.
  bool requiresRestartFrom(ScreenShareCapturePlan active) =>
      (frameRateLimitSupportedAtCapture &&
          requestedMaxFrameRate != active.requestedMaxFrameRate) ||
      (resolutionLimitSupportedAtCapture &&
          requestedParameters.dimensions !=
              active.requestedParameters.dimensions);
}
