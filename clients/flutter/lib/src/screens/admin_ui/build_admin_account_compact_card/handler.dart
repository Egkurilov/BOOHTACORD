import 'actions/handler.dart';
import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminBuildAdminAccountCompactCardBinding
    on AdminScreenStateContext {
  @override
  Widget adminBuildAdminAccountCompactCard(AdminAccount account) =>
      executeAdminBuildAdminAccountCompactCard(account);
}

extension AdminScreenStateAdminBuildAdminAccountCompactCardBindingAction
    on AdminScreenStateContext {
  Widget executeAdminBuildAdminAccountCompactCard(AdminAccount account) {
    final draft = adminAccountDrafts[account.accountId];
    final busy = adminBusyAccountIds.contains(account.accountId);
    final sameVoiceParticipant =
        widget.state.voiceChannel != null &&
        widget.state.room?.remoteParticipants.values.any((participant) {
              final metadata = participant.metadata;
              return metadata == 'account:${account.accountId}';
            }) ==
            true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GcColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GcColors.border),
      ),
      child: Material(
        color: GcColors.surface,
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: adminMemberAvatarColor(account.accountId),
            child: Text(adminMemberInitials(account.displayName)),
          ),
          title: Text(
            account.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              height: 20 / 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '@${account.login}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('role:${account.accountId}:${draft?.role}'),
              initialValue: draft?.role,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'Роль: ${account.login}'),
              items: const [
                DropdownMenuItem(value: 'MEMBER', child: Text('Участник')),
                DropdownMenuItem(
                  value: 'ADMINISTRATOR',
                  child: Text('Администратор'),
                ),
              ],
              onChanged: busy || draft == null
                  ? null
                  : (value) {
                      if (value != null) {
                        adminMutateView(() => draft.role = value);
                      }
                    },
            ),
            Material(
              color: GcColors.surface,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Заблокирован'),
                value: draft?.blocked ?? account.blocked,
                onChanged: busy || draft == null
                    ? null
                    : (value) => adminMutateView(() => draft.blocked = value),
              ),
            ),
            renderAdminCompactActions(account, busy, sameVoiceParticipant),
          ],
        ),
      ),
    );
  }
}
