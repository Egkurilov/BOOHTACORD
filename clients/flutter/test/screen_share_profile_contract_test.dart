import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = jsonDecode(
    File('../../contracts/screen-share-profile-v1.catalog.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final fixtures = jsonDecode(
    File('../../contracts/screen-share-profile-v1.fixtures.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final schema = jsonDecode(
    File('../../contracts/screen-share-profile-v1.schema.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('keeps descriptor enums and bounded reasons at schema v1', () {
    final properties = schema['properties'] as Map<String, dynamic>;
    expect(properties['schema_version']['const'], 1);
    expect(properties['publisher_state']['enum'], catalog['states']['publisher']);
    expect(properties['viewer_state']['enum'], catalog['states']['viewer']);
    expect(properties['reason_codes']['items']['enum'], catalog['reasonCodes']);
    expect(schema['required'], contains('scope'));
    expect(properties['scope']['required'], containsAll([
      'origin_id', 'account_id', 'room_id', 'media_session_id',
      'publication_generation', 'operation_revision',
    ]));
    final profileIds = <dynamic>[
      ...(catalog['existingProfiles'] as List).map((profile) => profile['id']),
      ...(catalog['experimentCandidates'] as List).map((profile) => profile['id']),
    ];
    expect(properties['requested_profile_id']['enum'], profileIds);
    expect(properties['effective_profile']['properties']['encoding']
        ['properties']['layers']['maxItems'], 2);
    for (final fixture in fixtures['enumValidation'] as List) {
      final values = properties[fixture['property']]?['enum'] as List? ?? const [];
      expect(values.contains(fixture['value']), fixture['accepted']);
    }
  });

  test('uses explicit current source-derived platform defaults', () {
    final policy = catalog['topologyPolicy'] as Map<String, dynamic>;
    final runtimes =
        policy['currentSourceDerivedByRuntime'] as Map<String, dynamic>;
    expect(policy['selectedVideoSubscriptionsPerViewer'], 1);
    expect(policy['maximumLayers'], 2);
    expect(runtimes.keys, containsAll(['web', 'flutterAndroid', 'flutterIOS', 'flutterDesktop']));
    expect(runtimes['flutterAndroid']['defaultProfileId'], 'P720_15');
    expect(runtimes['flutterAndroid']['primaryLayers'], {'min': 1, 'max': 1});
    expect(runtimes['flutterIOS']['defaultProfileId'], 'P720_15');
    expect(runtimes['flutterDesktop']['defaultProfileId'], 'P1080_30');
    expect(policy['backupCodecEvidenceStatus'], 'sfu-negotiated-unvalidated');
  });

  test('keeps legacy tracks readable and disables controls for unknown versions', () {
    final compatibility = fixtures['descriptorCompatibility'] as List;
    expect(compatibility[0]['descriptorVersion'], isNull);
    expect(compatibility[0]['legacyTrackReadable'], isTrue);
    expect(compatibility[0]['v1ControlsEnabled'], isFalse);
    expect(compatibility[1]['descriptorVersion'], 1);
    expect(compatibility[1]['v1ControlsEnabled'], isTrue);
    expect(compatibility[2]['descriptorVersion'], 99);
    expect(compatibility[2]['v1ControlsEnabled'], isFalse);
    for (final fixture in compatibility) {
      expect(fixture['fallbackAttempts'], 0);
    }
  });

  test('preserves all bit/s profile choices and keeps research profiles gated', () {
    expect(catalog['units']['bitrate'], 'bit/s');
    for (final profile in catalog['existingProfiles'] as List) {
      final quality = ScreenShareQuality(
        resolution: profile['resolution'] as int,
        frameRate: profile['frameRate'] as int,
      );
      expect(quality.maxBitrate * 1000, profile['bitrateBps']);
      expect(profile['id'], 'P${quality.resolution}_${quality.frameRate}');
    }
    final candidates = catalog['experimentCandidates'] as List;
    final research = candidates.singleWhere(
      (profile) => profile['id'] == 'motion-1440p60-v1',
    );
    expect(research['evidenceStatus'], 'research-only');
  });

  test('rejects unsupported profile dimensions and frame rates', () {
    expect(
      () => const ScreenShareQuality(resolution: 999, frameRate: 30).maxBitrate,
      throwsArgumentError,
    );
    expect(
      () => const ScreenShareQuality(resolution: 1080, frameRate: 90).maxBitrate,
      throwsArgumentError,
    );
  });
}
