import 'package:flutter/material.dart';

import 'controller.dart';
import 'model.dart';

class OwnSessionsView extends StatelessWidget {
  const OwnSessionsView({super.key, required this.state});
  final OwnSessionsController state;
  String date(BuildContext context, DateTime value) {
    final local = value.toLocal(), locale = MaterialLocalizations.of(context);
    return '${locale.formatShortDate(local)} ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
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
              : () => state.revoke(session.id),
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
                  : state.revokeOthers,
              child: const Text('Завершить все остальные'),
            ),
          ],
        ),
        const Text('Текущий сеанс останется активным.'),
      ],
    ),
  );
}
