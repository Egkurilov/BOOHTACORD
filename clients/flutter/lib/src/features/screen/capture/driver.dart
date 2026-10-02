import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../services/screen_share_quality.dart';
import 'android.dart';
import 'dimensions.dart';

abstract class ScreenShareDriver {
  Future<void> prepare(bool Function() active);
  Future<LocalVideoTrack> capture(ScreenShareCaptureOptions options);
  Future<void> publish(
    Room room,
    LocalVideoTrack track,
    ScreenShareQuality quality,
    VideoDimensions? dimensions,
  );
  Future<void> discard(Room room, LocalVideoTrack track);
  Future<void> stop(Room room);
  Future<void> disableBackground();
}

class NativeScreenShareDriver implements ScreenShareDriver {
  @override
  Future<void> prepare(bool Function() active) =>
      prepareAndroidScreenShare(active);
  @override
  Future<LocalVideoTrack> capture(ScreenShareCaptureOptions options) =>
      LocalVideoTrack.createScreenShareTrack(options);
  @override
  Future<void> publish(
    Room room,
    LocalVideoTrack track,
    ScreenShareQuality quality,
    VideoDimensions? dimensions,
  ) async {
    final participant = room.localParticipant;
    if (participant == null) throw StateError('Голосовое подключение закрыто.');
    await participant.publishVideoTrack(
      track,
      publishOptions: quality.publishOptions(
        // Preserve the Android single layer pending physical receiver acceptance.
        simulcast: defaultTargetPlatform != TargetPlatform.android,
        sourceDimensions:
            screenShareCaptureDimensions(track) ??
            (defaultTargetPlatform == TargetPlatform.windows
                ? dimensions
                : null),
      ),
    );
  }

  @override
  Future<void> discard(Room room, LocalVideoTrack track) async {
    try {
      final participant = room.localParticipant;
      final publications = participant?.videoTrackPublications.toList() ?? [];
      for (final publication in publications) {
        if (identical(publication.track, track)) {
          await participant!.removePublishedTrack(publication.sid);
        }
      }
    } finally {
      await track.stop();
    }
  }

  @override
  Future<void> stop(Room room) async {
    await room.localParticipant?.setScreenShareEnabled(false);
  }

  @override
  Future<void> disableBackground() => disableAndroidScreenShareBackground();
}
