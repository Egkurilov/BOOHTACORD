import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../../../services/screen_share_quality.dart';
import 'controller.dart';

extension ScreenShareStart on ScreenShareController {
  Future<void> startScreenShare({
    String? sourceId,
    ScreenShareQuality? quality,
    VideoDimensions? sourceDimensions,
  }) async {
    final ticket = scope.capture();
    final admitted = revision;
    await closing;
    if (disposed || !ticket.isActive || admitted != revision) return;
    final room = readRoom();
    if (room == null || room.localParticipant == null || !voiceReady()) {
      error = 'Подключитесь к голосовому каналу перед демонстрацией.';
      phase = ScreenSharePhase.error;
      changed();
      return;
    }
    if (starting != null || phase == ScreenSharePhase.sharing) return;
    phase = ScreenSharePhase.starting;
    error = null;
    this.quality = quality ?? this.quality;
    final expected = ++revision;
    final operation = publishCapture(
      room,
      ticket,
      expected,
      sourceId,
      sourceDimensions,
    );
    starting = operation;
    changed();
    try {
      await operation;
    } finally {
      if (identical(starting, operation)) starting = null;
    }
  }

  Future<void> publishCapture(
    Room room,
    SessionTicket ticket,
    int expected,
    String? sourceId,
    VideoDimensions? dimensions,
  ) async {
    bool active() => current(ticket, expected, room);
    LocalVideoTrack? pending;
    try {
      await driver.prepare(active);
      if (!active()) return;
      pending = await driver.capture(
        ScreenShareCaptureOptions(
          sourceId: sourceId,
          maxFrameRate: quality.captureFrameRate.toDouble(),
          params: quality.captureParameters,
        ),
      );
      if (!active()) return;
      await driver.publish(room, pending, quality, dimensions);
      if (!active()) return;
      published(room, pending);
      pending = null;
    } catch (cause) {
      if (active()) {
        stopSampling();
        phase = ScreenSharePhase.error;
        error =
            'Не удалось начать демонстрацию экрана: ${screenShareFailureDetail(cause)}';
        changed();
      }
    } finally {
      if (pending != null) {
        try {
          await driver.discard(room, pending);
        } catch (_) {}
      }
      if (!active() || phase != ScreenSharePhase.sharing) {
        await driver.disableBackground();
      }
    }
  }
}
