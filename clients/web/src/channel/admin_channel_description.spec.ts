import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import AdminChannelDescription from './AdminChannelDescription.vue'

describe('administrator channel description form', () => {
  it('styles the multiline editor within the topology inspector', () => {
    const css = readFileSync(new URL('../design/design_v2_admin_topology.css', import.meta.url), 'utf8')
    expect(css).toContain('.admin-topology-form--description textarea')
  })
  it('shows the server value and a bounded editor for the selected text channel', async () => {
    const html = await renderToString(createSSRApp(AdminChannelDescription, {
      channelId: 'channel-1', description: 'Общение на любые темы', revision: 8,
    }))
    expect(html).toContain('Описание канала')
    expect(html).toContain('Общение на любые темы')
    expect(html).toContain('maxlength="200"')
    expect(html).toContain('Сохранить описание')
  })
})
