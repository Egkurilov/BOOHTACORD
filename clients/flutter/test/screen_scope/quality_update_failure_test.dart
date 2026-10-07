import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';

import 'fakes.dart';
import 'quality_fakes.dart';

void main() {
  test('failure keeps the previously applied profile after recovery', () async {
    final driver = QualityScreenDriver()..failQualityUpdate = true;
    final track = FakeScreenTrack();
    final owner = qualityOwner(driver, track);
    addTearDown(owner.dispose);
    driver.appliedQuality = owner.quality;

    await owner.updateScreenShareQuality(
      const ScreenShareQuality(resolution: 1080, frameRate: 60),
    );

    expect(driver.qualityOutcomes, ['failure']);
    expect(driver.appliedQuality, ScreenShareQuality.balanced);
    expect(owner.quality, ScreenShareQuality.balanced);
    expect(owner.error, contains('Не удалось изменить качество'));
  });

  test('cleanup-required failure stops the active capture', () async {
    final driver = QualityScreenDriver()
      ..failQualityUpdate = true
      ..recoveryRestored = false;
    final track = FakeScreenTrack();
    final owner = qualityOwner(driver, track);
    addTearDown(owner.dispose);

    await owner.updateScreenShareQuality(
      const ScreenShareQuality(resolution: 1440, frameRate: 60),
    );

    expect(driver.qualityOutcomes, ['failure']);
    expect(driver.stopCalls, 1);
    expect(track.stopCalls, 1);
    expect(owner.activeTrack, isNull);
    expect(owner.phase, ScreenSharePhase.error);
    expect(owner.error, contains('Профиль не подтверждён'));
  });

  test('unclassified replacement failure stops an unconfirmed publisher', () async {
    final driver = QualityScreenDriver()..throwUnclassifiedFailure = true;
    final track = FakeScreenTrack();
    final owner = qualityOwner(driver, track);
    addTearDown(owner.dispose);

    await owner.updateScreenShareQuality(
      const ScreenShareQuality(resolution: 1440, frameRate: 60),
    );

    expect(driver.qualityOutcomes, ['failure']);
    expect(driver.stopCalls, 1);
    expect(track.stopCalls, 1);
    expect(owner.activeTrack, isNull);
    expect(owner.phase, ScreenSharePhase.error);
    expect(owner.error, contains('Профиль не подтверждён'));
  });
}
