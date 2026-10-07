import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../theme.dart';
import 'actions.dart';
import 'avatar.dart';
import 'state.dart';

class AdminMembersDesktopTable extends StatelessWidget {
  const AdminMembersDesktopTable({
    super.key,
    required this.controller,
    required this.accounts,
    required this.currentAccountId,
    required this.voiceParticipantIds,
    required this.actionFocusNode,
    required this.onSave,
    required this.onReset,
    required this.onKick,
  });
  final AdminMembersState controller;
  final List<AdminAccount> accounts;
  final String? currentAccountId;
  final Set<String> voiceParticipantIds;
  final FocusNode Function(String) actionFocusNode;
  final ValueChanged<AdminAccount> onSave;
  final ValueChanged<AdminAccount> onReset;
  final ValueChanged<AdminAccount> onKick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(children: [
      _header(),
      for (final account in accounts) _row(account),
    ]),
  );

  Widget _header() => const SizedBox(
    height: 44,
    child: Row(children: [
      Expanded(flex: 32, child: Text('Пользователь')),
      Expanded(flex: 37, child: Text('Роль')),
      Expanded(flex: 26, child: Text('Доступ')),
      SizedBox(width: 44),
    ]),
  );

  Widget _row(AdminAccount account) {
    final id = account.accountId;
    final draft = controller.drafts[id] ?? AdminMemberDraft.fromAccount(account);
    final busy = controller.busyAccountIds.contains(id);
    final canKick = voiceParticipantIds.contains(id) && id != currentAccountId;
    return Container(
      key: ValueKey('admin-member-row:$id'),
      height: 72,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: GcColors.borderSubtle))),
      child: Row(children: [
        Expanded(flex: 32, child: _identity(account)),
        Expanded(flex: 37, child: Text(_roleLabel(draft.role))),
        Expanded(flex: 26, child: Align(alignment: Alignment.centerLeft, child: _status(draft.blocked))),
        AdminMemberActions(
          account: account,
          draft: draft,
          busy: busy,
          canSave: controller.isDirty(id) && !controller.conflicts.containsKey(id),
          canKick: canKick,
          focusNode: actionFocusNode(id),
          onRole: () => controller.updateDraftRole(id, draft.role == 'ADMINISTRATOR' ? 'MEMBER' : 'ADMINISTRATOR'),
          onBlocked: () => controller.updateDraftBlocked(id, !draft.blocked),
          onSave: () => onSave(account),
          onReset: () => onReset(account),
          onKick: () => onKick(account),
        ),
      ]),
    );
  }

  Widget _identity(AdminAccount account) => Row(children: [
    AdminMemberAvatar(account: account),
    const SizedBox(width: 12),
    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(account.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      Text('@${account.login}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GcColors.textSecondary, fontSize: 12)),
    ])),
  ]);

  Widget _status(bool blocked) => DecoratedBox(
    decoration: BoxDecoration(color: blocked ? GcColors.dangerBackground : GcColors.successBackground, borderRadius: BorderRadius.circular(4)),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text(blocked ? 'Заблокирован' : 'Активен', style: TextStyle(color: blocked ? GcColors.danger : GcColors.success, fontSize: 12, fontWeight: FontWeight.w600))),
  );

  String _roleLabel(String role) => role == 'ADMINISTRATOR' ? 'Администратор' : 'Пользователь';
}
