import 'package:livekit_client/livekit_client.dart';

import '../../../services/screen_share_quality.dart';
import '../capture/dimensions.dart';
import '../lifecycle/controller.dart';

extension ScreenShareQualityUpdate on ScreenShareController {
  Future<void> updateScreenShareQuality(ScreenShareQuality quality) async {
    final ticket = scope.capture();
    final expected = revision;
    final room = readRoom();
    if (!ticket.isActive || disposed) return;
    if (phase != ScreenSharePhase.sharing) return;
    final track = readRoom()?.localParticipant
        ?.getTrackPublicationBySource(TrackSource.screenShareVideo)
        ?.track;
    if (track is! LocalVideoTrack || track.sender == null) {
      error = 'Активная видеодорожка демонстрации недоступна.';
      changed();
      return;
    }
    try {
      final sender = track.sender!;
      final parameters = sender.parameters;
      final encodings = parameters.encodings;
      if (encodings == null || encodings.isEmpty) {
        throw StateError('Видеоэнкодер не предоставил параметры качества.');
      }
      final source = screenShareCaptureDimensions(track);
      final baseScale = encodings
          .map((encoding) => encoding.scaleResolutionDownBy ?? 1.0)
          .reduce((left, right) => left < right ? left : right);
      for (final encoding in encodings) {
        final relativeScale =
            (encoding.scaleResolutionDownBy ?? 1.0) / baseScale;
        encoding.maxBitrate =
            (quality.maxBitrate * 1000 / (relativeScale * relativeScale))
                .round()
                .clamp(200000, quality.maxBitrate * 1000);
        encoding.maxFramerate = quality.frameRate;
        encoding.scaleResolutionDownBy = source == null
            ? relativeScale
            : quality.scaleResolutionDownBy(source) * relativeScale;
      }
      final applied = await sender.setParameters(parameters);
      if (!ticket.isActive ||
          expected != revision ||
          !identical(readRoom(), room) ||
          !identical(activeTrack, track)) {
        return;
      }
      if (applied == false) {
        throw StateError('Энкодер отклонил новые параметры.');
      }
      this.quality = quality;
      error = null;
    } catch (cause) {
      if (!ticket.isActive ||
          expected != revision ||
          !identical(activeTrack, track)) {
        return;
      }
      error =
          'Не удалось изменить качество: ${screenShareFailureDetail(cause)}';
    }
    changed();
  }
}
