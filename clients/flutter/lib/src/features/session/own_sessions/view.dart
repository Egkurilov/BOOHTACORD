import 'package:flutter/material.dart';

import '../../admin/confirmation/dialog.dart';
import 'controller.dart';
import 'model.dart';

class OwnSessionsView extends StatelessWidget {
  const OwnSessionsView({super.key, required this.state});
  final OwnSessionsController state;

  String date(BuildContext context, DateTime value) {
    final local = value.toLocal(), locale = MaterialLocalizations.of(context);
    return '${locale.formatShortDate(local)} ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  Future<void> confirmRevokeSession(
    BuildContext context,
    OwnSession session,
  ) async {
    final owner = state.accountId;
    final confirmed = await showConfirmationDialog<bool>(
      context: context,
      cancelOn: state,
      shouldCancel: () =>
          state.accountId != owner ||
          !state.items.any((item) => item.id == session.id && !item.current),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Подтвердите завершение сеанса'),
        content: Text(
          'Сеанс «${session.label}» потеряет доступ к сообщениям и голосу. '
          'Завершить его?',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Завершить сеанс'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        state.accountId == owner &&
        state.items.any((item) => item.id == session.id && !item.current)) {
      await state.revoke(session.id);
    }
  }

  Future<void> confirmRevokeOthers(BuildContext context) async {
    final owner = state.accountId;
    final confirmed = await showConfirmationDialog<bool>(
      context: context,
      cancelOn: state,
      shouldCancel: () =>
          state.accountId != owner || !state.items.any((item) => !item.current),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Подтвердите завершение сеансов'),
        content: const Text(
          'Все остальные сеансы потеряют доступ к сообщениям и голосу. '
          'Текущий сеанс останется активным. Продолжить?',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Завершить сеансы'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        state.accountId == owner &&
        state.items.any((item) => !item.current)) {
      await state.revokeOthers();
    }
  }

  Widget row(BuildContext context, OwnSession session) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${session.label}${session.current ? ' · Этот сеанс' : ''}'),
            Text('Вход: ${date(context, session.createdAt)}'),
            Text('Активность: ${date(context, session.lastActiveAt)}'),
          ],
        ),
        OutlinedButton(
          onPressed: state.busy || session.current
              ? null
              : () => confirmRevokeSession(context, session),
          child: const Text('Завершить'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 40),
        Text('Активные сеансы', style: Theme.of(context).textTheme.titleMedium),
        const Text('Завершённый сеанс потеряет доступ к сообщениям и голосу.'),
        if (state.error != null)
          Semantics(liveRegion: true, child: Text(state.error!)),
        if (state.busy)
          Semantics(liveRegion: true, child: const Text('Обновляем сеансы…')),
        for (final session in state.items) row(context, session),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: state.busy ? null : state.refresh,
              child: const Text('Обновить'),
            ),
            if (state.nextCursor != null)
              OutlinedButton(
                onPressed: state.busy ? null : state.more,
                child: const Text('Показать ещё'),
              ),
            OutlinedButton(
              onPressed: state.busy || !state.items.any((row) => !row.current)
                  ? null
                  : () => confirmRevokeOthers(context),
              child: const Text('Завершить все остальные'),
            ),
          ],
        ),
        const Text('Текущий сеанс останется активным.'),
      ],
    ),
  );
}
