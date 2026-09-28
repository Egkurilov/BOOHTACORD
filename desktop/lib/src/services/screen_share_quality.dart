import 'package:livekit_client/livekit_client.dart';

class ScreenShareQuality {
  const ScreenShareQuality({required this.resolution, required this.frameRate});

  static const resolutions = [720, 1080, 1440];
  static const frameRates = [15, 30, 60];

  final int resolution;
  final int frameRate;

  int get maxBitrate => switch (resolution) {
    720 => switch (frameRate) {
      15 => 1500,
      30 => 2500,
      _ => 4000,
    },
    1080 => switch (frameRate) {
      15 => 2500,
      30 => 5000,
      _ => 8000,
    },
    _ => switch (frameRate) {
      15 => 5000,
      30 => 8000,
      _ => 12000,
    },
  };

  String get estimatedBandwidth => maxBitrate >= 1000
      ? '≈ ${(maxBitrate / 1000).toStringAsFixed(maxBitrate % 1000 == 0 ? 0 : 1)} Мбит/с'
      : '≈ $maxBitrate Кбит/с';

  String get trackName => 'screenshare-${resolution}p-${frameRate}fps';

  VideoParameters get parameters => VideoParameters(
    dimensions: switch (resolution) {
      720 => VideoDimensionsPresets.h720_169,
      1080 => VideoDimensionsPresets.h1080_169,
      _ => VideoDimensionsPresets.h1440_169,
    },
    encoding: VideoEncoding(
      maxFramerate: frameRate,
      maxBitrate: maxBitrate * 1000,
    ),
  );

  /// Caps the longer source edge at the selected profile without changing
  /// orientation or stretching portrait captures.
  double scaleResolutionDownBy(VideoDimensions source) {
    final sourceMax = source.max();
    final targetMax = parameters.dimensions.max();
    if (source.width <= 0 || source.height <= 0 || sourceMax <= targetMax) {
      return 1;
    }

    // WebRTC's native encoder truncates scaled dimensions to integers. Pick a
    // nearby scale which keeps both output edges even, as required by common
    // hardware encoders.
    for (var offset = 0; offset <= 30; offset++) {
      final scale = sourceMax / (targetMax + offset);
      final scaledWidth = source.width ~/ scale;
      final scaledHeight = source.height ~/ scale;
      if (scaledWidth.isEven && scaledHeight.isEven) return scale;
    }
    return sourceMax / targetMax;
  }

  VideoPublishOptions publishOptions({
    required bool simulcast,
    VideoDimensions? sourceDimensions,
  }) {
    final encoding = parameters.encoding!;
    final scale = sourceDimensions == null
        ? 1.0
        : scaleResolutionDownBy(sourceDimensions);
    return VideoPublishOptions(
      name: trackName,
      screenShareEncoding: encoding.copyWith(scaleResolutionDownBy: scale),
      degradationPreference: DegradationPreference.maintainFramerate,
      simulcast: simulcast,
    );
  }

  static const balanced = ScreenShareQuality(resolution: 720, frameRate: 15);
  static const desktopDefault = ScreenShareQuality(
    resolution: 1080,
    frameRate: 30,
  );

  @override
  bool operator ==(Object other) =>
      other is ScreenShareQuality &&
      resolution == other.resolution &&
      frameRate == other.frameRate;

  @override
  int get hashCode => Object.hash(resolution, frameRate);
}
