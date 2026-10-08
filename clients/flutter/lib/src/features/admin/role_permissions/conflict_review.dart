import 'package:flutter/material.dart';

import '../../../theme.dart';
import '../../authorization/permissions/model.dart';

/// Explicit comparison for a concurrent role-permission edit.
class RolePermissionsConflictReview extends StatelessWidget {
  const RolePermissionsConflictReview({
    super.key,
    required this.before,
    required this.current,
    required this.proposed,
    required this.busy,
    required this.onRefresh,
    required this.onAcceptCurrent,
    required this.onKeepDraft,
  });

  final Map<GuildPermission, bool> before;
  final Map<GuildPermission, bool> current;
  final Map<GuildPermission, bool> proposed;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onAcceptCurrent;
  final VoidCallback onKeepDraft;

  static const _labels = {
    GuildPermission.textCreate: 'Текстовые · создавать',
    GuildPermission.textDelete: 'Текстовые · удалять',
    GuildPermission.voiceCreate: 'Голосовые · создавать',
    GuildPermission.voiceDelete: 'Голосовые · закрывать',
    GuildPermission.categoryCreate: 'Разделы · создавать',
    GuildPermission.categoryDelete: 'Разделы · удалять',
  };

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Сравнение конфликтующих разрешений',
    child: Container(
      key: const ValueKey('admin-role-conflict-review'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer
            .withValues(alpha: .22),
        border: Border.all(color: Theme.of(context).colorScheme.error),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Сравнение разрешений',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Другой администратор сохранил изменения. Выберите актуальные значения или оставьте свой черновик для повторного сохранения.',
          ),
          const SizedBox(height: 8),
          for (final permission in GuildPermission.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${_labels[permission]} · ${_mark(before[permission])} → ${_mark(current[permission])} · ваш черновик ${_mark(proposed[permission])}',
                style: const TextStyle(color: GcColors.textSecondary),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: busy ? null : onRefresh,
                child: const Text('Обновить актуальные значения'),
              ),
              OutlinedButton(
                onPressed: busy ? null : onAcceptCurrent,
                child: const Text('Принять серверные данные'),
              ),
              FilledButton.tonal(
                onPressed: busy ? null : onKeepDraft,
                child: const Text('Применить мой draft'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  String _mark(bool? value) => value == true ? 'вкл.' : 'выкл.';
}
