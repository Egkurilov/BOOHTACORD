import '../participant_member/component.dart';
import '../participant_muted/component.dart';
import '../participant_name/component.dart';
import '../voice_strip_person/component.dart';
import '../native_bindings.dart';

class WorkspaceVoiceParticipantStrip extends StatelessWidget {
  const WorkspaceVoiceParticipantStrip({
    super.key,
    required this.state,
    required this.localName,
    required this.localAvatarUrl,
    required this.localMuted,
    required this.localSpeaking,
    required this.participants,
  });

  final AppState state;
  final String localName;
  final String? localAvatarUrl;
  final bool localMuted;
  final bool localSpeaking;
  final List<RemoteParticipant> participants;

  @override
  Widget build(BuildContext context) => Container(
    height: 92,
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
    decoration: const BoxDecoration(
      color: GcColors.sidebar,
      border: Border(top: BorderSide(color: GcColors.border)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Участники',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                '${participants.length + 1} в комнате',
                style: const TextStyle(color: GcColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              WorkspaceVoiceStripPerson(
                state: state,
                name: localName,
                avatarUrl: localAvatarUrl,
                muted: localMuted,
                speaking: localSpeaking,
                microphoneUnavailable: state.microphoneUnavailable,
                deafened: state.deafened,
                screenSharing:
                    state.screenSharePhase == ScreenSharePhase.sharing,
              ),
              for (final participant in participants)
                WorkspaceVoiceStripPerson(
                  state: state,
                  name: workspaceParticipantName(participant),
                  avatarUrl: workspaceParticipantMember(
                    state,
                    participant,
                  )?.avatarUrl,
                  muted: workspaceParticipantMuted(participant),
                  speaking: participant.isSpeaking,
                  screenSharing: participant.videoTrackPublications.any(
                    (publication) =>
                        publication.source == TrackSource.screenShareVideo &&
                        !publication.muted,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
