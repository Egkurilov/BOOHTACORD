import 'dart:typed_data';

import 'package:livekit_client/livekit_client.dart';

class ScreenShareQuality {
  const ScreenShareQuality({required this.resolution, required this.frameRate});

  static const resolutions = [720, 1080, 1440];
  static const frameRates = [15, 30, 60];

  final int resolution;
  final int frameRate;

  /// Reads the dimensions from a JPEG desktop-source preview without decoding
  /// its pixels. The desktop capturer preview is a frame at the source's native
  /// size, which lets Windows set an aspect-preserving RTP resolution cap.
  static VideoDimensions? sourceDimensionsFromJpeg(Uint8List? bytes) {
    if (bytes == null ||
        bytes.length < 4 ||
        bytes[0] != 0xff ||
        bytes[1] != 0xd8) {
      return null;
    }

    const frameMarkers = {
      0xc0,
      0xc1,
      0xc2,
      0xc3,
      0xc5,
      0xc6,
      0xc7,
      0xc9,
      0xca,
      0xcb,
      0xcd,
      0xce,
      0xcf,
    };
    var offset = 2;
    while (offset + 3 < bytes.length) {
      if (bytes[offset] != 0xff) {
        offset++;
        continue;
      }
      while (offset < bytes.length && bytes[offset] == 0xff) {
        offset++;
      }
      if (offset >= bytes.length) return null;
      final marker = bytes[offset++];
      if (marker == 0xd9 || marker == 0xda) return null;
      if (marker == 0xd8 ||
          marker == 0x01 ||
          (marker >= 0xd0 && marker <= 0xd7)) {
        continue;
      }
      if (offset + 1 >= bytes.length) return null;
      final segmentLength = (bytes[offset] << 8) | bytes[offset + 1];
      if (segmentLength < 2 || offset + segmentLength > bytes.length) {
        return null;
      }
      if (frameMarkers.contains(marker)) {
        if (segmentLength < 7) return null;
        final height = (bytes[offset + 3] << 8) | bytes[offset + 4];
        final width = (bytes[offset + 5] << 8) | bytes[offset + 6];
        if (width <= 0 || height <= 0) return null;
        return VideoDimensions(width, height);
      }
      offset += segmentLength;
    }
    return null;
  }

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

  // The native capturer cannot raise its frame cap with applyConstraints.
  // Keep the source at the highest supported ceiling and tune the encoder.
  int get captureFrameRate => 60;
  VideoParameters get captureParameters =>
      const ScreenShareQuality(resolution: 1440, frameRate: 60).parameters;

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
