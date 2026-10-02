import 'package:livekit_client/livekit_client.dart';

import '../lifecycle/controller.dart';
import 'connection.dart';
import 'remote_tracks.dart';
import 'local_tracks.dart';

extension VoiceRoomEventsBind on VoiceController {
  void bindVoiceRoomEvents(Room room) {
    final ticket = scope.capture();
    final revision = operationRevision;
    bool owns() =>
        active(ticket, revision) &&
        (identical(this.room, room) || identical(pendingRoom, room));
    final listener = room.createListener();
    voiceEvents = listener;
    bindConnection(room, listener, owns);
    bindRemoteTracks(room, listener, owns);
    bindLocalTracks(room, listener, owns);
  }
}
