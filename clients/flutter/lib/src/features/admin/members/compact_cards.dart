import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../theme.dart';
import 'actions.dart';
import 'avatar.dart';
import 'state.dart';

class AdminMembersCompactCard extends StatelessWidget {
  const AdminMembersCompactCard({super.key, required this.controller, required this.account, required this.canKick, required this.focusNode, required this.onSave, required this.onReset, required this.onKick});
  final AdminMembersState controller;
  final AdminAccount account;
  final bool canKick;
  final FocusNode focusNode;
  final VoidCallback onSave, onReset, onKick;

  @override
  Widget build(BuildContext context) {
    final id = account.accountId;
    final draft = controller.drafts[id] ?? AdminMemberDraft.fromAccount(account);
    final busy = controller.busyAccountIds.contains(id);
    return Card(
      key: ValueKey('admin-member-card:$id'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 110),
        child: ExpansionTile(
          leading: AdminMemberAvatar(account: account),
          title: Row(children: [
            Expanded(child: Text(account.displayName, maxLines: 1, overflow: TextOverflow.ellipsis)),
            _badge(draft.blocked),
          ]),
          subtitle: Text('@${account.login}', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            AdminMemberActions(
              account: account, draft: draft, busy: busy,
              canSave: controller.isDirty(id) && !controller.conflicts.containsKey(id),
              canKick: canKick, focusNode: focusNode,
              onRole: () => controller.updateDraftRole(id, draft.role == 'ADMINISTRATOR' ? 'MEMBER' : 'ADMINISTRATOR'),
              onBlocked: () => controller.updateDraftBlocked(id, !draft.blocked),
              onSave: onSave, onReset: onReset, onKick: onKick,
            ),
            const Icon(Icons.expand_more),
          ]),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('admin-member-role:$id'),
              initialValue: draft.role,
              decoration: const InputDecoration(labelText: 'Роль'),
              items: const [
                DropdownMenuItem(value: 'MEMBER', child: Text('Пользователь')),
                DropdownMenuItem(value: 'ADMINISTRATOR', child: Text('Администратор')),
              ],
              onChanged: busy ? null : (value) { if (value != null) controller.updateDraftRole(id, value); },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Заблокирован'),
              value: draft.blocked,
              onChanged: busy ? null : (value) => controller.updateDraftBlocked(id, value),
            ),
            Row(children: [
              FilledButton.tonal(
                key: ValueKey('admin-member-save:$id'),
                onPressed: busy || !controller.isDirty(id) ? null : onSave,
                child: Text(busy ? 'Сохраняем…' : 'Сохранить'),
              ),
              const Spacer(),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _badge(bool blocked) => DecoratedBox(
    decoration: BoxDecoration(color: blocked ? GcColors.dangerBackground : GcColors.successBackground, borderRadius: BorderRadius.circular(4)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Text(blocked ? 'Закрыт' : 'Активен', style: TextStyle(color: blocked ? GcColors.danger : GcColors.success, fontSize: 11)),
    ),
  );
}
