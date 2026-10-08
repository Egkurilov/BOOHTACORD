import '../native_bindings.dart';

class WorkspaceVoiceRosterNavigationMembers extends StatelessWidget {
  const WorkspaceVoiceRosterNavigationMembers({
    super.key,
    required this.roster,
    required this.state,
  });

  final VoiceRoomRoster roster;
  final AppState state;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(40, 4, 8, 8),
    child: Column(
      children: [
        for (var index = 0; index < roster.participants.length; index++) ...[
          if (index > 0) const SizedBox(height: 4),
          VoiceRosterMemberRow(
            participant: roster.participants[index],
            state: state,
            compact: true,
          ),
        ],
      ],
    ),
  );
}
