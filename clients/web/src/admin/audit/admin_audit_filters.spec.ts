import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import AdminAuditFilters from './AdminAuditFilters.vue'

describe('administrator audit filter controls', () => {
  it('offers scope, local date bounds, type and real actor metadata', async () => {
    const html = await renderToString(createSSRApp(AdminAuditFilters, {
      filters: { scope: 'all' },
      events: [
        { id: '1', event_type: 'VOICE_LEASE_KICKED', created_at: '2026-10-04T10:00:00Z', actor_user_id: 'actor-1', actor_display_name: 'Егор' },
        { id: '2', event_type: 'CHANNEL_RENAMED', created_at: '2026-10-04T09:00:00Z' },
      ],
    }))
    for (const label of ['Область', 'С даты', 'По дату', 'Действие', 'Инициатор', 'Администрирование', 'Голос', 'Все']) {
      expect(html).toContain(label)
    }
    expect(html).toContain('Участник отключён от голоса')
    expect(html).toContain('Егор')
    expect(html).toContain('Система')
  })
})
