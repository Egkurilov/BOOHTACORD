import 'package:boohtacord_desktop/src/features/screen/profile/geometry.dart';
import 'package:boohtacord_desktop/src/services/screen_share_quality.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

import 'screen_share_contract_support.dart';

void main() {
  final catalog = readScreenShareContract('catalog');
  final fixtures = readScreenShareContract('fixtures');

  test('shares bit/s profiles and aspect-preserving geometry fixtures', () {
    for (final profile in catalog['existingProfiles']) {
      final quality = ScreenShareQuality(
        resolution: profile['resolution'],
        frameRate: profile['frameRate'],
      );
      expect(quality.maxBitrateBps, profile['bitrateBps']);
      expect(quality.maxBitrate, profile['bitrateBps'] ~/ 1000);
      expect(quality.parameters.encoding!.maxBitrate, profile['bitrateBps']);
    }
    for (final fixture in fixtures['geometry']) {
      final source = VideoDimensions(
        fixture['source']['width'],
        fixture['source']['height'],
      );
      final height = fixture['resolution'] as int;
      final target = VideoDimensions((height * 16 / 9).round(), height);
      final scale = ScreenProfileGeometry.scaleDownBy(
        source: source,
        target: target,
      );
      expect(
        {'width': source.width ~/ scale, 'height': source.height ~/ scale},
        fixture['expectedEncoded'],
      );
      expect(scale, greaterThanOrEqualTo(1));
    }
  });

  test('preserves legacy publication names and descriptor compatibility', () {
    final pattern = RegExp(catalog['compatibility']['legacyPublicationPattern']);
    for (final fixture in fixtures['legacyPublicationNames']) {
      final match = pattern.firstMatch(fixture['name']);
      final id = match == null ? null : 'P${match[1]}_${match[2]}';
      final known = catalog['existingProfiles'].any((profile) => profile['id'] == id);
      expect(match != null && id == fixture['profileId'] && known,
          fixture['accepted'], reason: fixture['name']);
    }
    final compatibility = fixtures['descriptorCompatibility'];
    expect(compatibility[0]['descriptorVersion'], isNull);
    expect(compatibility[0]['legacyTrackReadable'], isTrue);
    expect(compatibility[0]['v1ControlsEnabled'], isFalse);
    expect(compatibility[1]['descriptorVersion'], 1);
    expect(compatibility[1]['v1ControlsEnabled'], isTrue);
    expect(compatibility[2]['descriptorVersion'], 99);
    expect(compatibility[2]['v1ControlsEnabled'], isFalse);
    for (final item in compatibility) {
      expect(item['fallbackAttempts'], 0);
    }
  });

  test('keeps Flutter Android single-layer until device acceptance', () {
    final runtime = catalog['topologyPolicy']['currentSourceDerivedByRuntime'];
    expect(runtime['flutterAndroid'], {
      'simulcast': false,
      'primaryLayers': {'min': 1, 'max': 1},
      'defaultProfileId': 'P720_15',
      'evidenceStatus': 'source-derived-unvalidated',
    });
    expect(runtime['flutterIOS']['simulcast'], isFalse);
    expect(runtime['flutterDesktop']['primaryLayers'], {'min': 1, 'max': 1});
    expect(
      catalog['topologyPolicy']['backupCodecEvidenceStatus'],
      'sfu-negotiated-unvalidated',
    );
  });
}
