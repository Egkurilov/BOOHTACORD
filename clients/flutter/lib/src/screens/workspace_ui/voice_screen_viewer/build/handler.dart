import 'screen_stage/handler.dart';
import '../../selected_voice_screen_sender/component.dart';
import '../../voice_participant_account_id/component.dart';
import '../../voice_participant_strip/component.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceVoiceScreenViewerBuildBinding
    on WorkspaceVoiceScreenViewerContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceVoiceScreenViewerBuild(context);
  }
}

extension WorkspaceVoiceScreenViewerBuildAction
    on WorkspaceVoiceScreenViewerContext {
  Widget executeWorkspaceVoiceScreenViewerBuild(
    BuildContext context,
  ) => VoiceViewerLayout(
    stage: renderVoiceScreenViewerScreenStage(),
    diagnostics: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ScreenReceiverDiagnostics(
        track: receiverTrack,
        isLocal: showingLocalScreen,
        hasAudio: screenAudioAvailable,
        selectedStreamId: selectedIdentity,
        reportEnabled:
            !showingLocalScreen && selectedIdentity?.isNotEmpty == true,
        onReport: state.api.reportScreenShareMetrics,
        sourceTrackName: sourceTrackName,
        senderReport: showingLocalScreen ? state.screenShareSenderReport : null,
        senderSampledAt: showingLocalScreen
            ? state.screenShareSenderSampledAt
            : null,
        senderDescriptorJson: showingLocalScreen
            ? null
            : workspaceSelectedVoiceScreenSender(
                screens,
                selectedIdentity,
              )?.attributes[screenShareDescriptorAttribute],
        expectedSenderOrigin: Uri.parse(state.serverUrl).origin,
        expectedSenderAccountId:
            workspaceSelectedVoiceScreenSender(screens, selectedIdentity) ==
                null
            ? null
            : workspaceVoiceParticipantAccountId(
                workspaceSelectedVoiceScreenSender(screens, selectedIdentity)!,
              ),
        expectedRoomId: state.room?.name,
      ),
    ),
    audioControls: workspaceAudioControls,
    streamRail: workspaceStreamRail,
    participants: WorkspaceVoiceParticipantStrip(
      state: state,
      localName: localName,
      localAvatarUrl: state.profile?.avatarUrl,
      localMuted: localMuted,
      localSpeaking: localSpeaking,
      participants: participants,
    ),
  );
}
