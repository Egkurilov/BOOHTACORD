import '../../../models.dart';

typedef AuditActorOption = ({String id, String label});

const _eventTitles = <String, String>{
  'ACCOUNT_ADMIN_STATE_UPDATED': 'Изменены роль или доступ участника',
  'ADMINISTRATOR_RECOVERED': 'Восстановлен доступ администратора',
  'CATEGORIES_REORDERED': 'Изменён порядок категорий',
  'CATEGORY_CREATED': 'Создана категория',
  'CATEGORY_RENAMED': 'Переименована категория',
  'CHANNEL_CREATED': 'Создан канал',
  'CHANNEL_MOVED': 'Канал перемещён',
  'CHANNEL_RENAMED': 'Канал переименован',
  'CHANNELS_REORDERED': 'Изменён порядок каналов',
  'EMPTY_CATEGORY_DELETED': 'Удалена пустая категория',
  'HIDDEN_ATTACHMENT_CLEANUP': 'Удалён скрытый файл без ссылок',
  'INITIAL_ADMINISTRATOR_CREATED': 'Создан первый администратор',
  'LAST_ADMINISTRATOR_ACCESS_RECOVERED': 'Восстановлен доступ последнего администратора',
  'PASSWORD_CHANGED': 'Изменён пароль',
  'PASSWORD_RESET_APPLIED': 'Завершён сброс пароля',
  'PASSWORD_RESET_CREATED': 'Создана ссылка сброса пароля',
  'TEXT_CHANNEL_ARCHIVED': 'Текстовый канал архивирован',
  'TEXT_MESSAGE_DELETED': 'Удалено сообщение',
  'VOICE_CHANNEL_ADMISSION_CLOSED': 'Вход в голосовой канал закрыт',
  'VOICE_CHANNEL_ARCHIVED': 'Голосовой канал архивирован',
  'VOICE_LEASE_ISSUED': 'Создано голосовое подключение',
  'VOICE_LEASE_KICKED': 'Участник отключён от голоса',
  'VOICE_LEASE_RELEASED': 'Голосовое подключение завершено',
  'VOICE_LEASE_TRANSFERRED': 'Голосовое подключение перенесено',
};

String auditEventTitle(String type) =>
    _eventTitles[type] ?? 'Другое событие управления';

String auditActorLabel(AdminAuditEvent event) => event.actorUserId == null
    ? 'Система'
    : _accountLabel(event.actorDisplayName, event.actorLogin) ??
        'Удалённый аккаунт';

String? auditTargetLabel(AdminAuditEvent event) => event.targetUserId == null
    ? null
    : _accountLabel(event.targetDisplayName, event.targetLogin) ??
        'Удалённый аккаунт';

List<AuditActorOption> auditActorOptions(List<AdminAuditEvent> events) {
  final options = <String, String>{};
  for (final event in events) {
    options.putIfAbsent(event.actorUserId ?? 'system', () => auditActorLabel(event));
  }
  return options.entries
      .map((entry) => (id: entry.key, label: entry.value))
      .toList()
    ..sort((left, right) => left.label.compareTo(right.label));
}

String auditDayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

String auditDayLabel(DateTime date, {DateTime? now}) {
  const months = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];
  final today = now ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final current = DateTime(today.year, today.month, today.day);
  if (day == current) return 'Сегодня';
  if (day == current.subtract(const Duration(days: 1))) return 'Вчера';
  return '${day.day} ${months[day.month - 1]} ${day.year}';
}

String auditDateTime(DateTime date) {
  final local = date.toLocal();
  return '${_twoDigits(local.day)}.${_twoDigits(local.month)}.${local.year} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String auditClockTime(DateTime date) {
  final local = date.toLocal();
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String? _accountLabel(String? name, String? login) {
  final displayName = name?.trim();
  final handle = login?.trim();
  if (displayName?.isNotEmpty == true && handle?.isNotEmpty == true) {
    return '$displayName (@$handle)';
  }
  if (displayName?.isNotEmpty == true) return displayName;
  if (handle?.isNotEmpty == true) return '@$handle';
  return null;
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
