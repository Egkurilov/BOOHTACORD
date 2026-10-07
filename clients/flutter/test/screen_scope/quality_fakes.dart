import 'dart:async';

import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

import 'fakes.dart';

class QualityScreenDriver extends DelayedScreenDriver {
  int staleQualityWrites = 0;
  bool failQualityUpdate = false;
  bool recoveryRestored = true;
  ScreenShareQuality? appliedQuality;
  final qualityRequests = <ScreenShareQuality>[];
  final qualityOutcomes = <String>[];
  Completer<void>? updateGate;

  @override
  Future<bool> updateQuality(
    Room room,
    LocalVideoTrack track,
    ScreenShareQuality quality,
    VideoDimensions? dimensions,
    bool Function() isCurrent,
  ) async {
    qualityRequests.add(quality);
    if (qualityRequests.length == 1) await updateGate?.future;
    if (!isCurrent()) {
      qualityOutcomes.add('superseded');
      return false;
    }
    if (failQualityUpdate) {
      qualityOutcomes.add('failure');
      throw ScreenShareProfileUpdateException(
        'profile replacement failed',
        restored: recoveryRestored,
      );
    }
    appliedQuality = quality;
    qualityOutcomes.add('success');
    return true;
  }
}

ScreenShareController qualityOwner(
  QualityScreenDriver driver,
  FakeScreenTrack track, {
  SessionScope? scope,
}) {
  final room = FakeScreenRoom();
  final owner = ScreenShareController(
    ApiClient(),
    scope ?? SessionScope(),
    readRoom: () => room,
    voiceReady: () => true,
    driver: driver,
  );
  owner.activeTrack = track;
  owner.phase = ScreenSharePhase.sharing;
  return owner;
}
