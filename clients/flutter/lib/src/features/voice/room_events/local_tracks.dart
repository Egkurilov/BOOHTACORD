import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';
import '../../screen/lifecycle/controller.dart';

extension VoiceEventsLocalTracks on VoiceController {
  void bindLocalTracks(
    Room room,
    EventsListener<RoomEvent> listener,
    bool Function() owns,
  ) {
    listener.on<LocalTrackPublishedEvent>((event) {
      if (!owns()) return;
      if (!identical(this.room, room) ||
          event.publication.source != TrackSource.screenShareVideo) {
        return;
      }
      final track = event.publication.track;
      if (track is LocalVideoTrack) screen.published(room, track);
    });
    listener.on<LocalTrackUnpublishedEvent>((event) {
      if (!owns()) return;
      if (event.publication.source != TrackSource.screenShareVideo) return;
      final track = event.publication.track;
      screen.unpublished(room, track is LocalVideoTrack ? track : null);
    });
  }
}
