import 'participants_grid/handler.dart';
import '../../error_banner/component.dart';
import '../../people_word/component.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceVoiceParticipantRoomBuildBinding
    on WorkspaceVoiceParticipantRoomContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceVoiceParticipantRoomBuild(context);
  }
}

extension WorkspaceVoiceParticipantRoomBuildAction
    on WorkspaceVoiceParticipantRoomContext {
  Widget executeWorkspaceVoiceParticipantRoomBuild(
    BuildContext context,
  ) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.voicePhase == VoicePhase.reconnecting
                          ? 'Восстанавливаем связь'
                          : 'Все в сборе',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.voicePhase == VoicePhase.reconnecting
                          ? 'Состояние микрофона сохранено.'
                          : '${participants.length + 1} ${workspacePeopleWord(participants.length + 1)} в комнате'
                                '${screens.isEmpty ? '' : ' · демонстраций: ${screens.length}'}',
                      style: const TextStyle(color: GcColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (state.error != null) ...[
            const SizedBox(height: 18),
            WorkspaceErrorBanner(message: state.error!),
          ],
          if (state.microphoneUnavailable) ...[
            const SizedBox(height: 14),
            VoiceMicrophoneUnavailableNotice(
              useTouchPushToTalk:
                  state.usesTouchPushToTalk &&
                  state.audioActivationMode == AudioActivationMode.ptt,
              onRetry: state.audioActivationMode == AudioActivationMode.ptt
                  ? null
                  : () => unawaited(state.toggleMicrophone()),
            ),
          ],
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, gridConstraints) {
              final calculatedColumns =
                  ((gridConstraints.maxWidth + 12) / (160 + 12)).floor();
              final crossAxisCount = calculatedColumns < 1
                  ? 1
                  : calculatedColumns;
              final hasScreenShare =
                  participants.any(
                    (participant) => participant.videoTrackPublications.any(
                      (publication) =>
                          publication.source == TrackSource.screenShareVideo &&
                          !publication.muted,
                    ),
                  ) ||
                  state.screenSharePhase == ScreenSharePhase.sharing;
              // The native button keeps Material's 48 dp touch target; the
              // web share action is 30 px tall, so shared cards need the
              // additional vertical room rather than squeezing their content.
              final cardHeight = hasScreenShare ? 208.0 : 176.0;
              return renderVoiceParticipantRoomParticipantsGrid(
                crossAxisCount,
                cardHeight,
              );
            },
          ),
        ],
      ),
    ),
  );
}
