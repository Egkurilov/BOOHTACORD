import { createPinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import MentionPicker from './MentionPicker.vue'

describe('mention picker', () => {
  it('shows a selected recipient by name and allows keyboard selection in a DM', async () => {
    const app = createSSRApp(MentionPicker, {
      modelValue: ['user-2'], selfId: 'user-1', disabled: false,
      onlyParticipant: { id: 'user-2', displayName: 'Лера' },
    })
    app.use(createPinia())
    const html = await renderToString(app)
    expect(html).toContain('Упоминания')
    expect(html).toContain('Лера')
    expect(html).toContain('Убрать упоминание Лера')
    expect(html).not.toContain('user-2')
    expect(html).toContain('aria-expanded="false"')
    expect(html).toContain('aria-label="Выбрать упоминание"')
    expect(html).toMatch(/class="mention-picker-controls"[^>]* hidden/)
    expect(html.indexOf('class="mention-chip"')).toBeLessThan(html.indexOf('class="mention-picker-controls"'))
    const controlsId = html.match(/aria-controls="([^"]+)"/)?.[1]
    expect(controlsId).toBeTruthy()
    expect(html).toContain(`id="${controlsId}"`)
  })

  it('keeps TEXT participant controls collapsed until the disclosure is activated', async () => {
    const app = createSSRApp(MentionPicker, { modelValue: [], selfId: 'user-1', disabled: false })
    app.use(createPinia())
    const html = await renderToString(app)
    expect(html).toContain('aria-expanded="false"')
    expect(html).toMatch(/class="mention-picker-controls"[^>]* hidden/)
    expect(html).toContain('Загрузить участников')
    expect(html).not.toContain('class="mention-chip"')
  })

  it('disables the disclosure and chip removal while sending', async () => {
    const app = createSSRApp(MentionPicker, {
      modelValue: ['user-2'], selfId: 'user-1', disabled: true,
      onlyParticipant: { id: 'user-2', displayName: 'Лера' },
    })
    app.use(createPinia())
    const html = await renderToString(app)
    expect(html).toContain('class="mention-picker-trigger" type="button" disabled')
    expect(html).toContain('disabled aria-label="Убрать упоминание Лера"')
  })

  it('keeps selected ID chips but delegates a quick composer action to autocomplete', async () => {
    const app = createSSRApp(MentionPicker, { modelValue: ['user-2'], selfId: 'user-1', disabled: false, quick: true, onlyParticipant: { id: 'user-2', displayName: 'Лера' } })
    app.use(createPinia())
    const html = await renderToString(app)
    expect(html).toContain('Убрать упоминание Лера')
    expect(html).toContain('Выбрать упоминание')
    expect(html).not.toContain('mention-picker-controls')
    expect(html).not.toContain('Загрузить участников')
  })
})
