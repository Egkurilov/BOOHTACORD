import 'package:flutter/material.dart';

import '../../../../theme.dart';
import '../panel.dart';
import '../filter.dart';
import '../heading/presentation.dart';
import '../filters/presentation.dart';
import '../events/presentation.dart';
import '../loading/presentation.dart';

extension AuditLayoutPresentation on AdminAuditPanel {
  Widget renderAuditPanel(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final filtered = filterAdminAuditEvents(events, filters);
      final grouped = groupAdminAuditByDay(filtered);
      final header = renderAuditHeader();
      final filterBar = renderAuditFilters(context);
      final notice = Padding(
        padding: listPadding.copyWith(top: 0, bottom: 8),
        child: Text(
          'Фильтры применяются к ${events.length} уже загруженным записям. Для более ранних событий загрузите следующую страницу.',
          style: const TextStyle(color: GcColors.textSecondary, fontSize: 12),
        ),
      );
      final bodyChildren = renderAuditEvents(context, grouped);
      final body = Padding(
        padding: listPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: bodyChildren,
        ),
      );
      final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
      if (largeText ||
          MediaQuery.viewInsetsOf(context).bottom > 0 ||
          constraints.maxHeight < 500) {
        return ListView(
          key: const PageStorageKey('admin-audit-list'),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            header,
            filterBar,
            notice,
            if (loading && events.isEmpty)
              renderAuditLoading('Загружаем аудит…')
            else if (!loading && events.isEmpty && error == null)
              const _AuditEmptyState('Записей пока нет.')
            else if (!loading && filtered.isEmpty && filters.active)
              const _AuditEmptyState(
                'Среди загруженных записей совпадений нет.',
              )
            else
              body,
          ],
        );
      }
      return Column(
        children: [
          header,
          filterBar,
          notice,
          if (loading && events.isEmpty)
            renderAuditExpandedLoading('Загружаем аудит…')
          else if (!loading && events.isEmpty && error == null)
            const Expanded(child: Center(child: Text('Записей пока нет.')))
          else if (!loading && filtered.isEmpty && filters.active)
            const Expanded(
              child: Center(
                child: Text('Среди загруженных записей совпадений нет.'),
              ),
            )
          else
            Expanded(
              child: ListView(
                key: const PageStorageKey('admin-audit-list'),
                padding: listPadding,
                children: bodyChildren,
              ),
            ),
        ],
      );
    },
  );
}

class _AuditEmptyState extends StatelessWidget {
  const _AuditEmptyState(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(child: Text(message, textAlign: TextAlign.center)),
  );
}
