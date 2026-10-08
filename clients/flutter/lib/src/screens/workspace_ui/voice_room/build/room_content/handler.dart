import '../screen_viewer/handler.dart';
import '../ended_screen/handler.dart';
import '../room_header/handler.dart';
import '../../../error_banner/component.dart';
import '../../../voice_admission_closed_notice/component.dart';
import '../../../voice_participant_room/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension VoiceRoomRoomContentRenderer on WorkspaceVoiceRoomStateContext {
  Column renderVoiceRoomRoomContent(
    GuildChannel channel,
    String? selectedName,
    bool active,
    AppState state,
    int participantCount,
    BuildContext context,
    VideoTrack? viewerTrack,
    ScreenVideoRendererOwner rendererOwner,
    List<RemoteParticipant> screens,
    Object? viewerGeneration,
    RemoteParticipant? selectedScreen,
    RemoteTrackPublication<RemoteTrack>? selectedScreenPublication,
    VideoTrack? localScreenTrack,
    bool showingLocalScreen,
    VideoTrack? selectedTrack,
    LocalTrackPublication<LocalTrack>? localScreenPublication,
    Room? room,
    List<RemoteParticipant> participants,
    RemoteTrackPublication<RemoteAudioTrack>? selectedAudioPublication,
  ) => Column(
    children: [
      renderVoiceRoomRoomHeader(
        channel,
        selectedName,
        active,
        state,
        participantCount,
        context,
      ),
      if (active && state.screenShareError != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: WorkspaceErrorBanner(message: state.screenShareError!),
        ),
      if (channel.admissionClosed)
        WorkspaceVoiceAdmissionClosedNotice(
          error: state.voiceDisconnectNotice == null ? state.error : null,
          onLeave: active ? state.leaveVoice : null,
        ),
      Expanded(
        child: active
            ? viewerTrack != null
                  ? renderVoiceRoomScreenViewer(
                      state,
                      viewerTrack,
                      rendererOwner,
                      selectedName,
                      screens,
                      viewerGeneration,
                      selectedScreen,
                      selectedScreenPublication,
                      localScreenTrack,
                      showingLocalScreen,
                      selectedTrack,
                      localScreenPublication,
                      room,
                      participants,
                      selectedAudioPublication,
                    )
                  : widget.selectedScreenIdentity?.isNotEmpty == true
                  ? renderVoiceRoomEndedScreen(
                      selectedScreenPublication,
                      localScreenTrack,
                      state,
                      room,
                      screens,
                      participants,
                    )
                  : channel.admissionClosed
                  ? const SizedBox.shrink()
                  : WorkspaceVoiceParticipantRoom(
                      state: state,
                      room: room,
                      participants: participants,
                      screens: screens,
                      onScreenSelected: widget.onSelectScreen,
                    )
            : channel.admissionClosed
            ? const SizedBox.shrink()
            : VoicePrejoinCard(state: state, channel: channel),
      ),
    ],
  );
}
