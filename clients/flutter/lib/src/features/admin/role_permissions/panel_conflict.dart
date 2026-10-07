part of 'panel.dart';

extension _RolePermissionConflictView on RolePermissionsPanelState {
  Widget _conflictReviewView(double width) {
    final review = conflictReview!;
    return Card(
      key: const ValueKey('role-permission-conflict-review'),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Сравнение разрешений · версия ${review.revision}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(review.ready
                ? 'Сравнение готово для проверки'
                : 'Актуальные значения ещё не загружены.'),
            const SizedBox(height: 12),
            if (review.ready)
              width >= 720
                  ? _wideConflict(review)
                  : _compactConflict(review),
            const SizedBox(height: 12),
            _conflictActions(review),
          ],
        ),
      ),
    );
  }

  Widget _conflictActions(_PermissionConflict review) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton(
        onPressed: saving || loading ? null : _refreshConflict,
        child: const Text('Обновить сравнение'),
      ),
      TextButton(
        onPressed: saving || !review.ready ? null : _acceptServer,
        child: const Text('Принять актуальные с сервера'),
      ),
    ],
  );

  Widget _wideConflict(_PermissionConflict review) => Column(
    children: [
      const Row(children: [
        Expanded(flex: 2, child: Text('Разрешение')),
        Expanded(child: Text('До изменения')),
        Expanded(child: Text('Текущее на сервере')),
        Expanded(child: Text('Ваш вариант')),
      ]),
      for (final key in GuildPermission.values)
        Row(children: [
          Expanded(flex: 2, child: Text(_permissionLabels[key]!)),
          Expanded(
            child: _permissionValue(context, review.before[key] == true, 'before', key),
          ),
          Expanded(
            child: _permissionValue(context, review.current[key] == true, 'current', key),
          ),
          Expanded(
            child: _permissionValue(context, review.proposed[key] == true, 'proposed', key),
          ),
        ]),
    ],
  );

  Widget _compactConflict(_PermissionConflict review) => Column(
    children: [
      for (final key in GuildPermission.values)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_permissionLabels[key]!),
          subtitle: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _labeledValue('До изменения', review.before[key] == true, 'before', key),
              _labeledValue('Текущее на сервере', review.current[key] == true, 'current', key),
              _labeledValue('Ваш вариант', review.proposed[key] == true, 'proposed', key),
            ],
          ),
        ),
    ],
  );
}
