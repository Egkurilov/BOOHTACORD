import 'package:livekit_client/livekit_client.dart';

bool shouldCaptureSelectedRemoteScreenThumbnail({
  required TrackSource source,
  required bool isRemoteVideoTrack,
  required String participantIdentity,
  required String? selectedIdentity,
}) =>
    source == TrackSource.screenShareVideo &&
    isRemoteVideoTrack &&
    participantIdentity == selectedIdentity;

Future<void> captureSelectedRemoteScreenThumbnail({
  required Future<void> Function() capture,
  required TrackSource source,
  required bool isRemoteVideoTrack,
  required String participantIdentity,
  required String? selectedIdentity,
}) async {
  if (!shouldCaptureSelectedRemoteScreenThumbnail(
        source: source,
        isRemoteVideoTrack: isRemoteVideoTrack,
        participantIdentity: participantIdentity,
        selectedIdentity: selectedIdentity,
      )) {
    return;
  }
  await capture();
}
