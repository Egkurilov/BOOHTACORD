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

  test('keeps descriptor lifecycle and bounded reasons at schema v1', () {
    expect(schema['properties']['schema_version']['const'], 1);
    expect(schema['properties']['publisher_state']['enum'], catalog['states']['publisher']);
    expect(schema['properties']['viewer_state']['enum'], catalog['states']['viewer']);
    expect(schema['properties']['reason_codes']['items']['enum'], catalog['reasonCodes']);
    final profileIds = <dynamic>[
      ...(catalog['existingProfiles'] as List).map((profile) => profile['id']),
      ...(catalog['experimentCandidates'] as List).map((profile) => profile['id']),
    ];
    expect(schema['properties']['requested_profile_id']['enum'], profileIds);
    expect(schema['required'], contains('scope'));
    expect(schema['properties']['scope']['required'], [
      'origin_id',
      'account_id',
      'room_id',
      'media_session_id',
      'publication_generation',
      'operation_revision',
    ]);
    expect(
      schema['properties']['effective_profile']['properties']['encoding']['properties']['layers']['maxItems'],
      2,
    );
    expect(catalog['topologyPolicy']['selectedVideoSubscriptionsPerViewer'], 1);
    expect(catalog['topologyPolicy']['maximumLayers'], 2);
    final baselines = catalog['topologyPolicy']['baselineByRuntime'];
    expect(baselines['flutterAndroid'], {
      'simulcast': false,
      'primaryLayers': {'min': 1, 'max': 1},
      'evidenceStatus': 'source-derived-unvalidated',
    });
    expect(baselines['flutterOther'], {
      'simulcast': true,
      'primaryLayers': {'min': 1, 'max': 2},
      'lowLayerMaxFps': 15,
      'evidenceStatus': 'source-derived-unvalidated',
    });
    expect(catalog['topologyPolicy']['backupCodecEvidenceStatus'], 'sfu-negotiated-unvalidated');
    final properties = schema['properties'] as Map<String, dynamic>;
    for (final fixture in fixtures['enumValidation'] as List) {
      final values = properties[fixture['property']]?['enum'] as List? ?? const [];
      expect(values.contains(fixture['value']), fixture['accepted']);
    }
    final knownProfiles = <dynamic>[
      ...(catalog['existingProfiles'] as List),
      ...(catalog['experimentCandidates'] as List),
    ].map((profile) => profile['id']).toSet();
    for (final fixture in fixtures['descriptorCompatibility'] as List) {
      final accepted = fixture['schemaVersion'] == properties['schema_version']['const'] &&
          (properties['mode']['enum'] as List).contains(fixture['mode']) &&
          knownProfiles.contains(fixture['requestedProfileId']);
      expect(accepted, fixture['accepted']);
    }
    for (final fixture in fixtures['lifecycle'] as List) {
      expect(fixture['schemaVersion'], 1);
    }
    final lifecycle = fixtures['lifecycle'] as List;
    final stopped = lifecycle.singleWhere(
      (fixture) => fixture['name'].startsWith('stop-'),
    );
    expect(stopped['currentRevision'], greaterThan(stopped['completionRevision']));
    expect(stopped['expectedOutcome'], 'superseded');
    expect(stopped['mayPublish'], isFalse);
    final revoked = lifecycle.singleWhere(
      (fixture) => fixture['name'].startsWith('revoke-'),
    );
    expect(revoked['expectedOutcome'], 'session-revoked');
    expect(revoked['mayPublish'], isFalse);
    final reconnect = lifecycle.singleWhere(
      (fixture) => fixture['name'].startsWith('reconnect-'),
    );
    expect(reconnect['newGeneration'], greaterThan(reconnect['oldGeneration']));
    expect(reconnect['recapture'], isFalse);
  });
  test('preserves all current bitrate choices in bit/s and keeps research profiles gated', () {
    expect(catalog['units']['bitrate'], 'bit/s');
    for (final profile in catalog['existingProfiles'] as List) {
      final quality = ScreenShareQuality(
        resolution: profile['resolution'] as int,
        frameRate: profile['frameRate'] as int,
      );
      expect(quality.maxBitrate * 1000, profile['bitrateBps']);
      expect(profile['id'], 'P${quality.resolution}_${quality.frameRate}');
    }
    final research = (catalog['experimentCandidates'] as List).singleWhere(
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
