import '../../../core/session/scope.dart';
import '../profile/quality.dart';

abstract class ScreenAdaptationPort {
  ScreenRuntimeBinding? read();
  bool canApply(ScreenShareQuality target, ScreenRuntimeBinding binding);
  Future<bool> write(ScreenShareQuality target);
}

class ScreenRuntimeBinding {
  const ScreenRuntimeBinding({
    required this.ticket,
    required this.transportTicket,
    required this.server,
    required this.room,
    required this.track,
    required this.publication,
    required this.lifecycle,
    required this.writerRevision,
    required this.manualRevision,
    required this.generation,
    required this.current,
    required this.ceiling,
  });
  final SessionTicket ticket, transportTicket;
  final int server, lifecycle, writerRevision, manualRevision, generation;
  final Object room, track;
  final String publication;
  final ScreenShareQuality current, ceiling;
  bool get active => ticket.isActive && transportTicket.isActive;
  bool same(ScreenRuntimeBinding? next, {bool ownWrite = false}) =>
      next != null &&
      active &&
      next.active &&
      server == next.server &&
      identical(room, next.room) &&
      identical(track, next.track) &&
      lifecycle == next.lifecycle &&
      manualRevision == next.manualRevision &&
      generation == next.generation &&
      (ownWrite
          ? next.writerRevision == writerRevision + 1
          : writerRevision == next.writerRevision &&
                publication == next.publication);
}
