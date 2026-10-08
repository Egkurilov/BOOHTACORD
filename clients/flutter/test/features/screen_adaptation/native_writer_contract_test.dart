import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/features/screen/capture/driver.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';

import 'fixtures.dart';
import 'native_fixture.dart';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test('actual native driver delegates adapted profile to guarded SDK writer with same capture', () async {
    final f = NativeFixture(actualDriver: NativeScreenShareDriver());
    addTearDown(f.dispose);
    final participant = ContractParticipant();
    f.room.participant = participant;
    f.track.lastPublishOptions = high
        .publishOptions(simulcast: false)
        .copyWith(videoCodec: 'vp8');
    participant.publications = [FixturePublication(f.track, 'screen')];
    await f.pressure();
    expect(participant.calls, 1);
    expect(participant.receivedTrack, same(f.track));
    expect(participant.received!.screenShareEncoding!.maxFramerate, 60);
    expect(
      participant.received!.screenShareEncoding!.maxBitrate,
      low.maxBitrateBps,
    );
    expect(participant.received!.videoCodec, 'vp8');
    expect(participant.received!.simulcast, false);
    expect(participant.received!.backupVideoCodec.enabled, false);
    expect(f.owner.quality, low);
    expect(f.owner.userQualityCeiling, high);
    expect(f.owner.adaptation.state!.current, low);
  });
  test('actual restored writer failure retains confirmed quality and bounded attempts', () async {
    final f = NativeFixture(actualDriver: NativeScreenShareDriver());
    addTearDown(f.dispose);
    final participant = ContractParticipant()..restoreFailure = true;
    f.room.participant = participant;
    f.track.lastPublishOptions = high.publishOptions(simulcast: false);
    participant.publications = [FixturePublication(f.track, 'screen')];
    for (var i = 0; i < 24; i++) {
      f.now = 1000.0 + i * 10000;
      await f.owner.adaptation.step(window(f.now, generation: 0));
    }
    expect(participant.calls, 3);
    expect(f.owner.phase, ScreenSharePhase.sharing);
    expect(f.owner.quality, high);
    expect(f.owner.error, contains('Не удалось изменить качество'));
    expect(f.owner.adaptation.reason, 'attempt-limit');
  });
}

class ContractParticipant extends FixtureParticipant {
  int calls = 0;
  bool restoreFailure = false;
  LocalVideoTrack? receivedTrack;
  VideoPublishOptions? received;
  @override
  Future<LocalTrackPublication<LocalVideoTrack>?> updateScreenShareTrackProfile(
    LocalVideoTrack track, {
    required VideoPublishOptions publishOptions,
    required bool Function() isCurrent,
  }) async {
    calls++;
    expect(isCurrent(), true);
    if (restoreFailure) {
      throw ScreenShareProfileUpdateException(
        'fixture rollback',
        restored: true,
      );
    }
    receivedTrack = track;
    received = publishOptions;
    track.lastPublishOptions = publishOptions;
    final next = FixturePublication(track, 'updated-$calls');
    publications = [next];
    return next;
  }
}
