import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../theme.dart';
import 'state.dart';

class AdminMemberConflictReview extends StatelessWidget {
  const AdminMemberConflictReview({
    super.key,
    required this.conflict,
    required this.proposed,
    required this.busy,
    required this.onRefresh,
    required this.onDiscard,
    required this.onApply,
  });
  final AdminMemberConflict conflict;
  final AdminMemberDraft proposed;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onDiscard;
  final VoidCallback onApply;

  String _summary(String role, bool blocked) =>
      '${role == 'ADMINISTRATOR' ? 'Администратор' : 'Пользователь'} · ${blocked ? 'доступ закрыт' : 'доступ открыт'}';

  @override
  Widget build(BuildContext context) {
    final current = conflict.current;
    final ready = current?.updatedAt != null;
    return Card(
      key: ValueKey('admin-member-conflict:${conflict.before.accountId}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Аккаунт изменён другим администратором', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            _value('Было', _summary(conflict.before.role, conflict.before.blocked)),
            _value('Сейчас на сервере', current == null ? 'Нужно обновить данные' : _summary(current.role, current.blocked)),
            _value('Ваш черновик', _summary(proposed.role, proposed.blocked)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(onPressed: busy ? null : onRefresh, child: const Text('Обновить сравнение')),
              OutlinedButton(onPressed: busy || !ready ? null : onDiscard, child: const Text('Принять серверные данные')),
              FilledButton(onPressed: busy || !ready ? null : onApply, child: const Text('Проверено — оставить мой черновик')),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _value(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 160, child: Text(label, style: const TextStyle(color: GcColors.textSecondary))),
      Expanded(child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis)),
    ]),
  );
}
