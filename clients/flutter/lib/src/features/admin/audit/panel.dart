import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../theme.dart';
import 'filter.dart';

/// Presentation surface for the audit tab. Filtering and pagination state are
/// supplied by the workspace so changing tabs never recreates the draft state.
class AdminAuditPanel extends StatelessWidget {
  const AdminAuditPanel({
    super.key,
    required this.headerPadding,
    required this.listPadding,
    required this.events,
    required this.loading,
    required this.error,
    required this.cursor,
    required this.scope,
    required this.eventType,
    required this.from,
    required this.to,
    required this.actor,
    required this.onRefresh,
    required this.onScopeChanged,
    required this.onEventTypeChanged,
    required this.onActorChanged,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearFilters,
    required this.onLoadMore,
    required this.filters,
    required this.formatDate,
  });

  final EdgeInsets headerPadding;
  final EdgeInsets listPadding;
  final List<AdminAuditEvent> events;
  final bool loading;
  final String? error;
  final String? cursor;
  final AdminAuditScope scope;
  final String? eventType;
  final DateTime? from;
  final DateTime? to;
  final TextEditingController actor;
  final VoidCallback onRefresh;
  final ValueChanged<AdminAuditScope> onScopeChanged;
  final ValueChanged<String?> onEventTypeChanged;
  final VoidCallback onActorChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearFilters;
  final VoidCallback onLoadMore;
  final AdminAuditFilters filters;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final filtered = filterAdminAuditEvents(events, filters);
    final grouped = groupAdminAuditByDay(filtered);
    final compact = MediaQuery.sizeOf(context).width < 600;
    final eventTypes = events.map((event) => event.eventType).toSet().toList()
      ..sort();
    final header = Padding(
      padding: headerPadding,
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Аудит',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                Text(
                  'События управления без содержимого сообщений',
                  style: TextStyle(color: GcColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить'),
          ),
        ],
      ),
    );
    final filterBar = Padding(
      padding: listPadding.copyWith(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: compact ? double.infinity : 180,
            child: DropdownButtonFormField<AdminAuditScope>(
              key: const ValueKey('admin-audit-scope-filter'),
              isExpanded: true,
              initialValue: scope,
              decoration: const InputDecoration(labelText: 'Область'),
              items: const [
                DropdownMenuItem(
                  value: AdminAuditScope.all,
                  child: Text('Все события'),
                ),
                DropdownMenuItem(
                  value: AdminAuditScope.admin,
                  child: Text('Администрирование'),
                ),
                DropdownMenuItem(
                  value: AdminAuditScope.voice,
                  child: Text('Голос'),
                ),
              ],
              onChanged: (value) =>
                  onScopeChanged(value ?? AdminAuditScope.all),
            ),
          ),
          SizedBox(
            width: compact ? double.infinity : 220,
            child: TextField(
              controller: actor,
              decoration: const InputDecoration(labelText: 'Инициатор'),
              onChanged: (_) => onActorChanged(),
            ),
          ),
          SizedBox(
            width: compact ? double.infinity : 220,
            child: DropdownButtonFormField<String?>(
              key: ValueKey('admin-audit-type:$eventType'),
              isExpanded: true,
              initialValue: eventType,
              decoration: const InputDecoration(labelText: 'Тип события'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Все типы'),
                ),
                for (final type in eventTypes)
                  DropdownMenuItem<String?>(value: type, child: Text(type)),
              ],
              onChanged: onEventTypeChanged,
            ),
          ),
          OutlinedButton(
            key: const ValueKey('admin-audit-from-filter'),
            onPressed: onPickFrom,
            child: Text(from == null ? 'От даты' : 'От ${formatDate(from!)}'),
          ),
          OutlinedButton(
            key: const ValueKey('admin-audit-to-filter'),
            onPressed: onPickTo,
            child: Text(to == null ? 'До даты' : 'До ${formatDate(to!)}'),
          ),
          if (filters.active)
            TextButton(
              onPressed: onClearFilters,
              child: const Text('Сбросить фильтры'),
            ),
        ],
      ),
    );
    final notice = Padding(
      padding: listPadding.copyWith(top: 0, bottom: 8),
      child: Text(
        'Фильтры применяются к ${events.length} уже загруженным записям. Для более ранних событий загрузите следующую страницу.',
        style: const TextStyle(color: GcColors.textSecondary, fontSize: 12),
      ),
    );
    final bodyChildren = <Widget>[
      for (final entry in grouped.entries) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _dayLabel(entry.key),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        for (final event in entry.value) _eventRow(event),
      ],
      if (loading) const Center(child: CircularProgressIndicator()),
      if (cursor != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: loading ? null : onLoadMore,
            child: const Text('Показать более ранние'),
          ),
        ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(error!, style: const TextStyle(color: GcColors.danger)),
        ),
    ];
    final body = Padding(
      padding: listPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: bodyChildren,
      ),
    );
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    if (largeText) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          header,
          filterBar,
          notice,
          if (loading && events.isEmpty)
            _loadingContent('Загружаем аудит…')
          else if (!loading && events.isEmpty && error == null)
            const _AuditEmptyState('Записей пока нет.')
          else if (!loading && filtered.isEmpty && filters.active)
            const _AuditEmptyState('Среди загруженных записей совпадений нет.')
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
          _loadingState('Загружаем аудит…')
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
            child: ListView(padding: listPadding, children: bodyChildren),
          ),
      ],
    );
  }

  Widget _loadingContent(String message) => Center(
    child: Semantics(
      key: const ValueKey('admin-audit-loading'),
      liveRegion: true,
      label: message,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: GcColors.textSecondary),
      ),
    ),
  );

  Widget _loadingState(String message) =>
      Expanded(child: _loadingContent(message));

  Widget _eventRow(AdminAuditEvent event) {
    final actorLabel = _accountLabel(
      event.actorDisplayName,
      event.actorLogin,
      fallback: event.actorUserId == null ? 'Система' : 'Удалённый аккаунт',
    );
    final target = event.targetUserId == null
        ? null
        : _accountLabel(
            event.targetDisplayName,
            event.targetLogin,
            fallback: 'Удалённый аккаунт',
          );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GcColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GcColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
            _title(event.eventType),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('Инициатор · $actorLabel'),
          trailing: Text(
            formatDate(event.createdAt),
            style: const TextStyle(color: GcColors.textSecondary, fontSize: 11),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Тип · ${event.eventType}'),
            ),
            if (target != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Объект · $target'),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Время · ${formatDate(event.createdAt)}'),
            ),
          ],
        ),
      ),
    );
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Сегодня';
    if (day == yesterday) return 'Вчера';
    return '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}';
  }

  String _accountLabel(
    String? displayName,
    String? login, {
    required String fallback,
  }) {
    final name = displayName?.trim();
    final handle = login?.trim();
    if (name?.isNotEmpty == true && handle?.isNotEmpty == true) {
      return '$name (@$handle)';
    }
    if (name?.isNotEmpty == true) return name!;
    if (handle?.isNotEmpty == true) return '@$handle';
    return fallback;
  }

  String _title(String eventType) => switch (eventType) {
    'ACCOUNT_ADMIN_STATE_UPDATED' => 'Изменены роль или доступ участника',
    'ADMINISTRATOR_RECOVERED' => 'Восстановлен доступ администратора',
    'CATEGORIES_REORDERED' => 'Изменён порядок категорий',
    'CATEGORY_CREATED' => 'Создана категория',
    'CATEGORY_RENAMED' => 'Переименована категория',
    'CHANNEL_CREATED' => 'Создан канал',
    'CHANNEL_MOVED' => 'Канал перемещён',
    'CHANNEL_RENAMED' => 'Канал переименован',
    'CHANNELS_REORDERED' => 'Изменён порядок каналов',
    'EMPTY_CATEGORY_DELETED' => 'Удалена пустая категория',
    'HIDDEN_ATTACHMENT_CLEANUP' => 'Удалён скрытый файл без ссылок',
    'INITIAL_ADMINISTRATOR_CREATED' => 'Создан первый администратор',
    'LAST_ADMINISTRATOR_ACCESS_RECOVERED' =>
      'Восстановлен доступ последнего администратора',
    'PASSWORD_CHANGED' => 'Изменён пароль',
    'PASSWORD_RESET_APPLIED' => 'Завершён сброс пароля',
    'PASSWORD_RESET_CREATED' => 'Создана ссылка сброса пароля',
    'TEXT_CHANNEL_ARCHIVED' => 'Текстовый канал архивирован',
    'TEXT_MESSAGE_DELETED' => 'Удалено текстовое сообщение',
    'VOICE_CHANNEL_ADMISSION_CLOSED' => 'Вход в голосовой канал закрыт',
    'VOICE_CHANNEL_ARCHIVED' => 'Голосовой канал архивирован',
    'VOICE_LEASE_ISSUED' => 'Создано голосовое подключение',
    'VOICE_LEASE_KICKED' => 'Участник отключён от голоса',
    'VOICE_LEASE_RELEASED' => 'Голосовое подключение завершено',
    'VOICE_LEASE_TRANSFERRED' => 'Голосовое подключение перенесено',
    _ => 'Другое событие управления',
  };
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
