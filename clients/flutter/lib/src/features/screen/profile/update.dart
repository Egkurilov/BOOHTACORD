import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../capture/dimensions.dart';
import 'quality.dart';

Future<bool> updateScreenShareProfile(
  Room room,
  LocalVideoTrack track,
  ScreenShareQuality quality,
  VideoDimensions? dimensions,
  bool Function() isCurrent,
) async {
  final participant = room.localParticipant;
  if (participant == null) throw StateError('Голосовое подключение закрыто.');
  final previous = track.lastPublishOptions;
  if (previous == null) throw StateError('Профиль демонстрации недоступен.');
  final source = screenShareCaptureDimensions(track) ??
      (defaultTargetPlatform == TargetPlatform.windows ? dimensions : null);
  final profile = quality.publishOptions(
    simulcast: previous.simulcast,
    sourceDimensions: source,
  );
  final publication = await participant.updateScreenShareTrackProfile(
    track,
    publishOptions: previous.copyWith(
      name: profile.name,
      screenShareEncoding: profile.screenShareEncoding,
      degradationPreference: profile.degradationPreference,
    ),
    isCurrent: isCurrent,
  );
  return publication != null && isCurrent();
}
