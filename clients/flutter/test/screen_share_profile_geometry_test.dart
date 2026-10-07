import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  final fixtures = jsonDecode(
    File('../../contracts/screen-share-profile-v1.fixtures.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('matches shared aspect-preserving and even-dimension fixtures', () {
    for (final fixture in fixtures['geometry'] as List) {
      final quality = ScreenShareQuality(
        resolution: fixture['resolution'] as int,
        frameRate: fixture['frameRate'] as int,
      );
      final source = VideoDimensions(
        fixture['source']['width'] as int,
        fixture['source']['height'] as int,
      );
      final dimensions = quality.parameters.dimensions;
      final target = source.height > source.width
          ? VideoDimensions(dimensions.height, dimensions.width)
          : dimensions;
      final scale = quality.scaleResolutionDownBy(source);
      final width = source.width ~/ scale;
      final height = source.height ~/ scale;

      expect(scale, greaterThanOrEqualTo(1));
      expect(width, fixture['expectedEncoded']['width']);
      expect(height, fixture['expectedEncoded']['height']);
      expect(width, lessThanOrEqualTo(target.width));
      expect(height, lessThanOrEqualTo(target.height));
      if (source.width >= 2 && source.height >= 2) {
        expect(width.isEven, isTrue);
        expect(height.isEven, isTrue);
      }
      expect(width / height, closeTo(source.width / source.height, 0.01));
    }
  });
}
