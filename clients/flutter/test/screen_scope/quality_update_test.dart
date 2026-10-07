import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';

import 'fakes.dart';
import 'quality_fakes.dart';

void _useLiveUpdatePlatform() {
  final previousPlatform = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);
}

void main() {
  test('success applies the selected profile to the same capture', () async {
    _useLiveUpdatePlatform();
    final driver = QualityScreenDriver();
    final track = FakeScreenTrack();
    final owner = qualityOwner(driver, track);
    owner.quality = ScreenShareQuality.balanced;
    addTearDown(owner.dispose);

    await owner.updateScreenShareQuality(
      const ScreenShareQuality(resolution: 1080, frameRate: 30),
    );

    expect(owner.activeTrack, same(track));
    expect(owner.quality, const ScreenShareQuality(resolution: 1080, frameRate: 30));
    expect(driver.qualityOutcomes, ['success']);
  });

  test('stop cancels profile update before any stale write', () async {
    _useLiveUpdatePlatform();
    final driver = QualityScreenDriver()
      ..updateGate = Completer<void>()
      ..staleOutcome = 'cancel';
    final scope = SessionScope();
    final track = FakeScreenTrack();
    final owner = qualityOwner(driver, track, scope: scope);
    owner.quality = ScreenShareQuality.balanced;
    addTearDown(owner.dispose);
    final update = owner.updateScreenShareQuality(
      const ScreenShareQuality(resolution: 1440, frameRate: 60),
    );
    await Future<void>.delayed(Duration.zero);

    final stop = owner.stopScreenShare();
    scope.close();
    driver.updateGate!.complete();
    await Future.wait([update, stop]);

    expect(owner.phase, ScreenSharePhase.idle);
    expect(owner.quality, ScreenShareQuality.balanced);
    expect(driver.staleQualityWrites, 0);
    expect(driver.qualityOutcomes, ['cancel']);
    expect(track.stopCalls, 1);
  });

  test('latest profile supersedes in-flight and queued profiles', () async {
    _useLiveUpdatePlatform();
    final driver = QualityScreenDriver()..updateGate = Completer<void>();
    final track = FakeScreenTrack();
    final owner = qualityOwner(driver, track);
    owner.quality = ScreenShareQuality.balanced;
    addTearDown(owner.dispose);
    final first = owner.updateScreenShareQuality(
      const ScreenShareQuality(resolution: 720, frameRate: 30),
    );
    await Future<void>.delayed(Duration.zero);
    final middle = owner.updateScreenShareQuality(
      const ScreenShareQuality(resolution: 1080, frameRate: 30),
    );
    final latest = owner.updateScreenShareQuality(
      const ScreenShareQuality(resolution: 1440, frameRate: 60),
    );
    driver.updateGate!.complete();
    await Future.wait([first, middle, latest]);

    expect(driver.qualityRequests, [
      const ScreenShareQuality(resolution: 720, frameRate: 30),
      const ScreenShareQuality(resolution: 1440, frameRate: 60),
    ]);
    expect(driver.qualityOutcomes, ['superseded', 'success']);
    expect(owner.quality, const ScreenShareQuality(resolution: 1440, frameRate: 60));
    expect(driver.staleQualityWrites, 0);
  });

}
