import type { AuditEvent } from '../../identity/admin_directory_client'

const eventTitles: Record<string, string> = {
  ACCOUNT_ADMIN_STATE_UPDATED: 'Изменены роль или доступ участника',
  ADMINISTRATOR_RECOVERED: 'Восстановлен доступ администратора',
  CATEGORIES_REORDERED: 'Изменён порядок категорий',
  CATEGORY_CREATED: 'Создана категория',
  CATEGORY_RENAMED: 'Переименована категория',
  CHANNEL_CREATED: 'Создан канал',
  CHANNEL_MOVED: 'Канал перемещён',
  CHANNEL_RENAMED: 'Канал переименован',
  CHANNELS_REORDERED: 'Изменён порядок каналов',
  EMPTY_CATEGORY_DELETED: 'Удалена пустая категория',
  HIDDEN_ATTACHMENT_CLEANUP: 'Удалён скрытый файл без ссылок',
  INITIAL_ADMINISTRATOR_CREATED: 'Создан первый администратор',
  LAST_ADMINISTRATOR_ACCESS_RECOVERED: 'Восстановлен доступ последнего администратора',
  PASSWORD_CHANGED: 'Изменён пароль',
  PASSWORD_RESET_APPLIED: 'Завершён сброс пароля',
  PASSWORD_RESET_CREATED: 'Создана ссылка сброса пароля',
  TEXT_CHANNEL_ARCHIVED: 'Текстовый канал архивирован',
  TEXT_MESSAGE_DELETED: 'Удалено сообщение',
  VOICE_CHANNEL_ADMISSION_CLOSED: 'Вход в голосовой канал закрыт',
  VOICE_CHANNEL_ARCHIVED: 'Голосовой канал архивирован',
  VOICE_LEASE_ISSUED: 'Создано голосовое подключение',
  VOICE_LEASE_KICKED: 'Участник отключён от голоса',
  VOICE_LEASE_RELEASED: 'Голосовое подключение завершено',
  VOICE_LEASE_TRANSFERRED: 'Голосовое подключение перенесено',
}

function accountLabel(displayName?: string, login?: string): string | null {
  const name = displayName?.trim()
  const handle = login?.trim()
  if (name && handle) return `${name} (@${handle})`
  if (name) return name
  return handle ? `@${handle}` : null
}

export function presentAuditEvent(event: AuditEvent): { title: string; actor: string; target?: string } {
  const actor = event.actor_user_id
    ? accountLabel(event.actor_display_name, event.actor_login) ?? 'Удалённый аккаунт'
    : 'Система'
  const target = event.target_user_id
    ? accountLabel(event.target_display_name, event.target_login) ?? 'Удалённый аккаунт'
    : undefined
  return { title: eventTitles[event.event_type] ?? 'Другое событие управления', actor, ...(target ? { target } : {}) }
}
