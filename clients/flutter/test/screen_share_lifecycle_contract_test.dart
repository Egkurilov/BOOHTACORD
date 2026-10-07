import 'package:flutter_test/flutter_test.dart';

import 'screen_share_contract_support.dart';

void main() {
  final catalog = readScreenShareContract('catalog');
  final fixtures = readScreenShareContract('fixtures');
  final schema = readScreenShareContract('schema');

  test('accepts and rejects shared descriptor fixtures', () {
    for (final sample in fixtures['descriptorCases']) {
      final Map<String, dynamic> descriptor = {
        ...fixtures['validDescriptor'],
        ...sample['overrides'],
      };
      expect(
        acceptsScreenShareDescriptor(descriptor, schema),
        sample['accepted'],
        reason: sample['name'],
      );
    }
  });

  test('documents lifecycle gates and unvalidated quality acceptance', () {
    expect(catalog['topologyPolicy']['dynacastOwner'], 'LiveKit/WebRTC SDK');
    final lifecycle = {
      for (final item in fixtures['lifecycle']) item['name']: item,
    };
    expect(
      lifecycle.keys,
      containsAll([
        'stop-invalidates-pending-update',
        'revoke-wins-pending-start',
        'logout-invalidates-pending-start',
        'publish-failure-rolls-back-screen-only',
        'reconnect-reuses-capture',
        'retry-keeps-generation',
        'new-user-start-gets-session',
      ]),
    );
    expect(lifecycle['logout-invalidates-pending-start']['reasonCode'], 'logout');
    expect(lifecycle['publish-failure-rolls-back-screen-only']['microphoneReleased'], isFalse);
    expect(lifecycle['reconnect-reuses-capture']['recapture'], isFalse);
    expect(lifecycle['retry-keeps-generation']['newGeneration'],
        lifecycle['retry-keeps-generation']['oldGeneration']);
    expect(lifecycle['restart-after-source-ended']['userActionRequired'], isTrue);
    expect(lifecycle['new-user-start-gets-session']['mediaSessionId'],
        isNot(lifecycle['new-user-start-gets-session']['oldMediaSessionId']));

    final acceptance = catalog['qualityAcceptance'];
    expect(acceptance['status'], 'proposed-unvalidated');
    expect(acceptance['warmupSeconds'], 30);
    expect(acceptance['durationSeconds'], 180);
    expect(acceptance['windowSeconds'], 1);
    expect(acceptance['repeats'], 5);
    expect(acceptance['presentedFpsP05'], 55);
    expect(acceptance['latencyP95Ms']['firstFrame'], 2000);
    expect(acceptance['latencyP95Ms']['profileSwitch'], 2000);
    expect(acceptance['freezeThresholdMs'], 500);
    expect(acceptance['fpsObservation'], contains('presented'));
  });
}
