import 'package:flutter/foundation.dart';

import '../lifecycle/controller.dart';
import '../profile/quality.dart';
import 'port.dart';

class NativeScreenAdaptationPort implements ScreenAdaptationPort {
  NativeScreenAdaptationPort(this.owner);
  final ScreenShareController owner;
  @override
  ScreenRuntimeBinding? read() {
    final room = owner.readRoom(), track = owner.activeTrack;
    if (owner.disposed ||
        owner.phase != ScreenSharePhase.sharing ||
        room == null ||
        track == null ||
        owner.qualityUpdateOperation != null) {
      return null;
    }
    String? publication;
    for (final item in room.localParticipant?.videoTrackPublications ?? []) {
      if (identical(item.track, track)) publication = item.sid;
    }
    if (publication == null || publication.isEmpty) return null;
    final session = owner.api.transport.session;
    return ScreenRuntimeBinding(
      ticket: owner.scope.capture(),
      transportTicket: session.scope.capture(),
      server: session.serverRevision,
      room: room,
      track: track,
      publication: publication,
      lifecycle: owner.revision,
      writerRevision: owner.qualityIntentRevision,
      manualRevision: owner.manualQualityRevision,
      generation: owner.metrics.gate.generation,
      current: owner.quality,
      ceiling: owner.userQualityCeiling ?? owner.quality,
    );
  }

  @override
  bool canApply(ScreenShareQuality target, ScreenRuntimeBinding binding) =>
      !target
          .capturePlan(defaultTargetPlatform)
          .requiresRestartFrom(
            binding.current.capturePlan(defaultTargetPlatform),
          );
  @override
  Future<bool> write(ScreenShareQuality target) async {
    await owner.updateScreenShareQuality(target, fromSupervisor: true);
    return !owner.disposed &&
        owner.phase == ScreenSharePhase.sharing &&
        owner.quality == target &&
        owner.error == null;
  }
}
