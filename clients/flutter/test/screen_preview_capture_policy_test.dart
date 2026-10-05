import 'package:boohtacord_desktop/src/features/voice/screen_preview/capture_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test(
    'dispatches capture when selected remote screen is subscribed',
    () async {
      var captures = 0;
      await captureSelectedRemoteScreenThumbnail(
        temporaryPreview: false,
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
    'does not dispatch capture for audio, unselected or preview subscriptions',
    () async {
      var captures = 0;
      Future<void> attempt({
        required TrackSource source,
        required bool isRemoteVideoTrack,
        required String? selectedIdentity,
        bool temporaryPreview = false,
      }) => captureSelectedRemoteScreenThumbnail(
        temporaryPreview: temporaryPreview,
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
      await attempt(
        source: TrackSource.screenShareVideo,
        isRemoteVideoTrack: true,
        selectedIdentity: 'screen-owner',
        temporaryPreview: true,
      );

      expect(captures, 0);
    },
  );
}
