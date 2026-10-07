import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../profile/quality.dart';
import '../lifecycle/controller.dart';

bool _isCurrentSession(
  ScreenShareController owner,
  SessionTicket ticket,
  int expected,
  Room? room,
) =>
    !owner.disposed &&
    ticket.isActive &&
    expected == owner.revision &&
    room != null &&
    identical(owner.readRoom(), room);

extension ScreenShareQualityUpdate on ScreenShareController {
  Future<void> updateScreenShareQuality(ScreenShareQuality requested) {
    if (disposed || phase != ScreenSharePhase.sharing) return Future.value();
    final track = activeTrack;
    if (track == null) {
      error = 'Активная видеодорожка демонстрации недоступна.';
      changed();
      return Future.value();
    }
    qualityIntentRevision++;
    pendingQualityUpdate = requested;
    pendingQualityTicket = scope.capture();
    pendingQualityRoom = readRoom();
    pendingQualityLifecycleRevision = revision;
    final current = qualityUpdateOperation;
    if (current != null) return current;
    final operation = Future<void>.microtask(_drainQualityUpdates);
    qualityUpdateOperation = operation;
    unawaited(operation.whenComplete(() {
      if (identical(qualityUpdateOperation, operation)) {
        qualityUpdateOperation = null;
      }
    }));
    return operation;
  }

  Future<void> _drainQualityUpdates() async {
    while (pendingQualityUpdate != null) {
      final requested = pendingQualityUpdate!;
      final ticket = pendingQualityTicket!;
      final room = pendingQualityRoom;
      final lifecycleRevision = pendingQualityLifecycleRevision;
      final intentRevision = qualityIntentRevision;
      pendingQualityUpdate = null;
      final track = activeTrack;
      bool current() =>
          !disposed &&
          intentRevision == qualityIntentRevision &&
          _isCurrentSession(this, ticket, lifecycleRevision, room) &&
          phase == ScreenSharePhase.sharing &&
          identical(activeTrack, track);
      if (track == null || room == null || !current()) continue;
      try {
        final applied = await driver.updateQuality(
          room,
          track,
          requested,
          sourceDimensions,
          current,
        );
        if (!current()) continue;
        if (!applied) throw StateError('Новый профиль не был опубликован.');
        quality = requested;
        error = null;
      } catch (cause) {
        if (current()) {
          if (cause is! ScreenShareProfileUpdateException || !cause.restored) {
            final reason = screenShareFailureDetail(cause);
            final detail =
                'Профиль не подтверждён; демонстрация остановлена: $reason';
            await stopScreenShare();
            if (!disposed) {
              phase = ScreenSharePhase.error;
              error = detail;
            }
          } else {
            error = 'Не удалось изменить качество: ${screenShareFailureDetail(cause)}';
          }
        }
      }
      changed();
    }
  }

}
