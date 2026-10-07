import 'dart:math' as math;

import 'package:livekit_client/livekit_client.dart';

class ScreenProfileGeometry {
  static double scaleDownBy({
    required VideoDimensions source,
    required VideoDimensions target,
  }) {
    if (source.width <= 0 || source.height <= 0) return 1;
    final portrait = source.height > source.width;
    final targetWidth = portrait ? target.height : target.width;
    final targetHeight = portrait ? target.width : target.height;
    final initialScale = math.max(
      1.0,
      math.max(source.width / targetWidth, source.height / targetHeight),
    ).toDouble();
    if (source.width < 2 || source.height < 2) return initialScale;

    final sourceLongEdge = source.max();
    final largestEncodedEdge = (sourceLongEdge / initialScale).floor();
    for (var reduction = 0; reduction <= 30; reduction++) {
      final encodedLongEdge = largestEncodedEdge - reduction;
      if (encodedLongEdge < 2) break;
      final scale = sourceLongEdge / encodedLongEdge;
      final width = source.width ~/ scale;
      final height = source.height ~/ scale;
      if (width.isEven &&
          height.isEven &&
          width <= targetWidth &&
          height <= targetHeight) {
        return scale;
      }
    }
    return initialScale;
  }
}
