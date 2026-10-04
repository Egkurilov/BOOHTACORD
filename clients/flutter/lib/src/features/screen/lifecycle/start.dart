import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../../../services/screen_share_diagnostics.dart';
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
    var publishing = false;
    try {
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.captureRequested,
        platform: defaultTargetPlatform,
      );
      await driver.prepare(active);
      if (!active()) return;
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.capturePrepared,
        platform: defaultTargetPlatform,
      );
      pending = await driver.capture(
        ScreenShareCaptureOptions(
          sourceId: sourceId,
          maxFrameRate: quality.captureFrameRate.toDouble(),
          params: quality.captureParameters,
        ),
      );
      if (!active()) return;
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.captureCreated,
        platform: defaultTargetPlatform,
        trackEnabled: screenShareTrackEnabled(pending),
      );
      publishing = true;
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.publishStarted,
        platform: defaultTargetPlatform,
        trackEnabled: screenShareTrackEnabled(pending),
        localScreenPublications: screenShareLocalPublicationCount(room),
      );
      await driver.publish(room, pending, quality, dimensions);
      if (!active()) return;
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.publishCompleted,
        platform: defaultTargetPlatform,
        trackEnabled: screenShareTrackEnabled(pending),
        localScreenPublications: screenShareLocalPublicationCount(room),
      );
      published(room, pending);
      pending = null;
    } catch (cause) {
      logScreenShareDiagnostic(
        publishing
            ? ScreenShareDiagnosticEvent.publishFailed
            : ScreenShareDiagnosticEvent.captureFailed,
        platform: defaultTargetPlatform,
        trackEnabled: screenShareTrackEnabled(pending),
        localScreenPublications: screenShareLocalPublicationCount(room),
        errorType: cause.runtimeType.toString(),
      );
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
