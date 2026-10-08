import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension MembersPanelMemberGroupsRenderer
    on WorkspaceMembersPanelStateContext {
  Expanded renderMembersPanelMemberGroups(
    List<({List<GuildMember> members, String title})> groups,
    BuildContext context,
  ) => Expanded(
    child: RefreshIndicator(
      onRefresh: state.refreshMembers,
      child: ListView(
        children: [
          if (state.membersError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      state.membersError!,
                      style: const TextStyle(color: GcColors.danger),
                    ),
                  ),
                  TextButton(
                    onPressed: state.membersLoading
                        ? null
                        : state.refreshMembers,
                    child: Text(
                      state.membersLoading ? 'Загружаем…' : 'Повторить',
                    ),
                  ),
                ],
              ),
            )
          else if (state.membersLoading && state.members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Загружаем участников…',
                style: TextStyle(color: GcColors.muted),
              ),
            )
          else if (state.members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'В гильдии пока нет участников.',
                style: TextStyle(color: GcColors.muted),
              ),
            ),
          for (final group in groups)
            if (group.members.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    '${group.title} — ${group.members.length}',
                    style: const TextStyle(
                      color: GcColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              for (final member in group.members)
                workspaceMemberRow(context, member),
            ],
        ],
      ),
    ),
  );
}
