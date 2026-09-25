import { describe, expect, it } from 'vitest'

import { presentAuditEvent } from './audit_event_display'

const knownTypes = [
  'ACCOUNT_ADMIN_STATE_UPDATED', 'ADMINISTRATOR_RECOVERED', 'CATEGORIES_REORDERED', 'CATEGORY_CREATED',
  'CATEGORY_RENAMED', 'CHANNEL_CREATED', 'CHANNEL_MOVED', 'CHANNEL_RENAMED', 'CHANNELS_REORDERED',
  'EMPTY_CATEGORY_DELETED', 'HIDDEN_ATTACHMENT_CLEANUP', 'INITIAL_ADMINISTRATOR_CREATED',
  'LAST_ADMINISTRATOR_ACCESS_RECOVERED', 'PASSWORD_CHANGED', 'PASSWORD_RESET_APPLIED',
  'PASSWORD_RESET_CREATED', 'TEXT_CHANNEL_ARCHIVED', 'TEXT_MESSAGE_DELETED',
  'VOICE_CHANNEL_ADMISSION_CLOSED', 'VOICE_CHANNEL_ARCHIVED', 'VOICE_LEASE_ISSUED',
  'VOICE_LEASE_KICKED', 'VOICE_LEASE_RELEASED', 'VOICE_LEASE_TRANSFERRED',
]

describe('administrator audit presentation', () => {
  it('localizes every currently emitted audit type', () => {
    for (const eventType of knownTypes) {
      const view = presentAuditEvent({ id: '1', event_type: eventType, created_at: '2026-09-25T00:00:00Z' })
      expect(view.title).not.toBe('Другое событие управления')
      expect(view.title).not.toContain('_')
    }
  })

  it('shows current names and logins without rendering internal IDs', () => {
    const view = presentAuditEvent({
      id: '1', event_type: 'ACCOUNT_ADMIN_STATE_UPDATED', created_at: '2026-09-25T00:00:00Z',
      actor_user_id: 'private-actor-id', actor_display_name: 'Администратор', actor_login: 'admin_fixture',
      target_user_id: 'private-target-id', target_display_name: 'Альфа', target_login: 'alpha_fixture',
    })
    expect(view).toEqual({ title: 'Изменены роль или доступ участника', actor: 'Администратор (@admin_fixture)', target: 'Альфа (@alpha_fixture)' })
    expect(JSON.stringify(view)).not.toContain('private-')
  })

  it('uses safe labels when a user is absent or an event type is unknown', () => {
    const view = presentAuditEvent({ id: '2', event_type: 'FUTURE_EVENT', created_at: '2026-09-25T00:00:00Z', target_user_id: 'private-target-id' })
    expect(view).toEqual({ title: 'Другое событие управления', actor: 'Система', target: 'Удалённый аккаунт' })
  })
})
