import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'
import SettingsWorkspaceHeader from './SettingsWorkspaceHeader.vue'

describe('shared settings workspace header', () => {
  it.each([
    ['audio', 'Настройки аудио', 'Закрыть настройки аудио'],
    ['profile', 'Настройки', 'Закрыть настройки'],
    ['admin', 'Администрирование', 'Закрыть администрирование'],
  ] as const)('preserves the %s title and navigation contract', async (panel, title, closeLabel) => {
    const html = await renderToString(createSSRApp(SettingsWorkspaceHeader, { panel, navExpanded: true }))
    expect(html).toContain(`<strong>${title}</strong>`)
    expect(html).toContain(`aria-label="${closeLabel}"`)
    expect(html).toContain('aria-controls="nav-sidebar" aria-expanded="true"')
    expect(html).not.toContain('members-panel')
    expect(html).toContain('class="settings-workspace-icon-wrap"')
    expect(html).toContain(panel === 'admin' ? 'm12 2 9 4' : 'cx="12" cy="11" r="3"')
  })

  it('reports collapsed navigation without hiding its accessible control in markup', async () => {
    const html = await renderToString(createSSRApp(SettingsWorkspaceHeader, { panel: 'audio', navExpanded: false }))
    expect(html).toContain('aria-label="Открыть навигацию"')
    expect(html).toContain('aria-controls="nav-sidebar" aria-expanded="false"')
  })
})
