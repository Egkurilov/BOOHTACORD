import '../panel.dart';

extension AuditEventLabels on AdminAuditPanel {
  String auditDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Сегодня';
    if (day == yesterday) return 'Вчера';
    return '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}';
  }

  String auditAccountLabel(
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

  String auditTitle(String eventType) => switch (eventType) {
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
