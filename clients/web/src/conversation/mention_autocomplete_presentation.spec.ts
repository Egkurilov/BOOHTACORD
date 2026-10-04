import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'
import MentionAutocomplete from './MentionAutocomplete.vue'

describe('mention autocomplete presentation', () => {
  it('offers the DM participant as soon as the @ action opens', async () => {
    const html = await renderToString(createSSRApp(MentionAutocomplete, {
      modelValue: '@', mentionUserIds: [], selfId: 'self', disabled: false,
      onlyParticipant: { id: 'other', displayName: 'Лера' },
    }))
    expect(html).toContain('Подсказки упоминаний')
    expect(html).toContain('Лера')
    expect(html).toContain('role="option"')
    expect(html).not.toContain('Загрузить участников')
  })
})
