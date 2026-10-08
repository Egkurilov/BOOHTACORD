import '../member_groups/handler.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension MembersPanelPopoverSurfaceRenderer
    on WorkspaceMembersPanelStateContext {
  ColoredBox renderMembersPanelPopoverSurface(
    List<({List<GuildMember> members, String title})> groups,
    BuildContext context,
  ) => ColoredBox(
    color: GcColors.sidebar,
    child: Padding(
      key: const ValueKey('members-panel'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'УЧАСТНИКИ',
                  style: TextStyle(
                    color: GcColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .7,
                  ),
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: 'Закрыть участников',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: 14),
          renderMembersPanelMemberGroups(groups, context),
        ],
      ),
    ),
  );
}
