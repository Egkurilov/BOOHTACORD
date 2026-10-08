import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension MemberProfilePopoverMemberSummaryRenderer
    on WorkspaceMemberProfilePopoverStateContext {
  Row renderMemberProfilePopoverMemberSummary(GuildMember member) => Row(
    children: [
      AuthenticatedAvatar(
        state: widget.state,
        name: member.displayName,
        avatarUrl: member.avatarUrl,
        radius: 32,
        backgroundColor: GcColors.avatarViolet,
        fallbackFontSize: 20,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: GcColors.text,
                fontSize: 20,
                height: 28 / 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '@${member.login}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: GcColors.textSecondary,
                fontSize: 14,
                height: 20 / 14,
              ),
            ),
            Text(
              member.role == 'ADMINISTRATOR' ? 'Администратор' : 'Участник',
              style: const TextStyle(
                color: GcColors.muted,
                fontSize: 12,
                height: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
