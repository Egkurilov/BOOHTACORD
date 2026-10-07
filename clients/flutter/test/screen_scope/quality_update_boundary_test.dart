import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';

import 'fakes.dart';
import 'quality_fakes.dart';

final _lifecycleFixtures = jsonDecode(
  File('../../contracts/screen-share-publisher-lifecycle-v1.fixtures.json')
      .readAsStringSync(),
) as Map<String, dynamic>;

String _outcome(String id) => (_lifecycleFixtures['cases'] as List)
    .cast<Map<String, dynamic>>()
    .firstWhere((item) => item['id'] == id)['outcome'] as String;

void main() {
  test('server switch cancels a pending profile and closes its capture', () async {
    final driver = QualityScreenDriver()
      ..updateGate = Completer<void>()
      ..staleOutcome = _outcome('stop-during-apply');
    final scope = SessionScope();
    final track = FakeScreenTrack();
    final firstRoom = FakeScreenRoom();
    var currentRoom = firstRoom;
    final owner = qualityOwner(
      driver,
      track,
      scope: scope,
      readRoom: () => currentRoom,
    );
    addTearDown(owner.dispose);

    final update = owner.updateScreenShareQuality(
      const ScreenShareQuality(resolution: 1440, frameRate: 60),
    );
    await Future<void>.delayed(Duration.zero);
    scope.close();
    currentRoom = FakeScreenRoom();
    final stop = owner.stopScreenShare();
    driver.updateGate!.complete();
    await Future.wait([update, stop]);

    expect(driver.qualityOutcomes, [_outcome('stop-during-apply')]);
    expect(driver.appliedQuality, isNull);
    expect(driver.staleQualityWrites, 0);
    expect(owner.quality, ScreenShareQuality.balanced);
    expect(owner.activeTrack, isNull);
    expect(track.stopCalls, 1);
  });

  test('OS projection stop cancels update without restarting capture', () async {
    final driver = QualityScreenDriver()
      ..updateGate = Completer<void>()
      ..staleOutcome = _outcome('stop-during-apply');
    final track = FakeScreenTrack();
    final owner = qualityOwner(driver, track);
    addTearDown(owner.dispose);
    final room = FakeScreenRoom();
    final update = owner.updateScreenShareQuality(
      const ScreenShareQuality(resolution: 1440, frameRate: 60),
    );
    await Future<void>.delayed(Duration.zero);

    owner.unpublished(room, track);
    final stop = owner.closing!;
    driver.updateGate!.complete();
    await Future.wait([update, stop]);

    expect(driver.qualityOutcomes, [_outcome('stop-during-apply')]);
    expect(driver.appliedQuality, isNull);
    expect(driver.staleQualityWrites, 0);
    expect(driver.backgroundDisableCalls, 1);
    expect(owner.activeTrack, isNull);
    expect(owner.phase, ScreenSharePhase.idle);
  });
}
