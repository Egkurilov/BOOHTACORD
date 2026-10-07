part of 'panel.dart';

extension _RolePermissionActionBar on RolePermissionsPanelState {
  void _cancelDraft() {
    setState(() {
      draft = Map.of(baseline);
      conflictReview = null;
      error = null;
      status = null;
    });
  }

  Widget _actionBar(double width) => SafeArea(
    top: false,
    child: Container(
      key: const ValueKey('role-permissions-action-bar'),
      padding: EdgeInsets.fromLTRB(
        width < 600 ? 12 : 24,
        8,
        width < 600 ? 12 : 24,
        8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: role == GuildRole.member ? _memberActions() : _readOnlyLabel(),
    ),
  );

  Widget _memberActions() {
    final review = conflictReview;
    if (review != null) {
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: saving ? null : _cancelDraft,
            child: const Text('Отменить'),
          ),
          FilledButton(
            onPressed: saving || !review.ready
                ? null
                : () => _save(reviewedConflict: true),
            child: const Text('Проверено — применить мой вариант'),
          ),
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: saving || loading ? null : _setDefaults,
          child: const Text('По умолчанию'),
        ),
        TextButton(
          onPressed: !dirty || saving ? null : _cancelDraft,
          child: const Text('Отменить'),
        ),
        FilledButton(
          onPressed: !dirty || saving || loading ? null : () => _save(),
          child: Text(saving ? 'Сохраняем…' : 'Сохранить'),
        ),
      ],
    );
  }

  Widget _readOnlyLabel() => const Align(
    alignment: Alignment.centerRight,
    child: Text('Просмотр роли'),
  );
}
