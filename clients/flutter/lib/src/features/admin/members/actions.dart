import 'package:flutter/material.dart';

import '../../../models.dart';
import 'state.dart';

class AdminMemberActions extends StatelessWidget {
  const AdminMemberActions({
    super.key,
    required this.account,
    required this.draft,
    required this.busy,
    required this.canSave,
    required this.canKick,
    required this.focusNode,
    required this.onRole,
    required this.onBlocked,
    required this.onSave,
    required this.onReset,
    required this.onKick,
  });
  final AdminAccount account;
  final AdminMemberDraft draft;
  final bool busy;
  final bool canSave;
  final bool canKick;
  final FocusNode focusNode;
  final VoidCallback onRole;
  final VoidCallback onBlocked;
  final VoidCallback onSave;
  final VoidCallback onReset;
  final VoidCallback onKick;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: ValueKey('admin-member-actions:${account.accountId}'),
    tooltip: 'Действия с участником ${account.displayName}',
    enabled: !busy,
    focusNode: focusNode,
    onSelected: (action) {
      switch (action) {
        case 'role': onRole(); break;
        case 'blocked': onBlocked(); break;
        case 'save': onSave(); break;
        case 'reset': onReset(); break;
        case 'kick': onKick(); break;
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(value: 'role', child: Text('Роль: ${draft.role == 'ADMINISTRATOR' ? 'Администратор' : 'Пользователь'}')),
      PopupMenuItem(value: 'blocked', child: Text(draft.blocked ? 'Снять блокировку' : 'Заблокировать')),
      const PopupMenuDivider(),
      PopupMenuItem(value: 'save', enabled: !busy && canSave, child: const Text('Сохранить')),
      PopupMenuItem(value: 'reset', enabled: !busy, child: const Text('Сбросить пароль')),
      if (canKick) const PopupMenuItem(value: 'kick', enabled: true, child: Text('Отключить от голоса')),
    ],
    child: const SizedBox.square(
      dimension: 44,
      child: Center(child: Icon(Icons.more_horiz)),
    ),
  );
}
