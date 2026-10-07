import 'package:boohtacord_desktop/src/features/voice/screen_preview/capture_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/features/voice/remote_tracks/subscriptions.dart';

void main() {
  test('automatically subscribes to microphones but never screen video', () {
    expect(shouldAutomaticallySubscribeRemoteTrack(TrackSource.microphone), isTrue);
    expect(shouldAutomaticallySubscribeRemoteTrack(TrackSource.screenShareVideo), isFalse);
    expect(shouldAutomaticallySubscribeRemoteTrack(TrackSource.screenShareAudio), isFalse);
  });

  test(
    'captures a selected remote screen only after its video subscription exists',
    () async {
      var captures = 0;
      await captureSelectedRemoteScreenThumbnail(
        capture: () async => captures++,
        source: TrackSource.screenShareVideo,
        isRemoteVideoTrack: true,
        participantIdentity: 'screen-owner',
        selectedIdentity: 'screen-owner',
      );

      expect(captures, 1);
    },
  );

  test(
    'does not capture audio, local video, or an unselected screen',
    () async {
      var captures = 0;
      Future<void> attempt({
        required TrackSource source,
        required bool isRemoteVideoTrack,
        required String? selectedIdentity,
      }) => captureSelectedRemoteScreenThumbnail(
        capture: () async => captures++,
        source: source,
        isRemoteVideoTrack: isRemoteVideoTrack,
        participantIdentity: 'screen-owner',
        selectedIdentity: selectedIdentity,
      );

      await attempt(
        source: TrackSource.microphone,
        isRemoteVideoTrack: true,
        selectedIdentity: 'screen-owner',
      );
      await attempt(
        source: TrackSource.screenShareVideo,
        isRemoteVideoTrack: false,
        selectedIdentity: 'screen-owner',
      );
      await attempt(
        source: TrackSource.screenShareVideo,
        isRemoteVideoTrack: true,
        selectedIdentity: null,
      );
      await attempt(
        source: TrackSource.screenShareVideo,
        isRemoteVideoTrack: true,
        selectedIdentity: 'another-screen-owner',
      );
      expect(captures, 0);
    },
  );
}
