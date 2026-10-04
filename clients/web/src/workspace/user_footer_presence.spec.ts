import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'
import WorkspaceUserFooter from './WorkspaceUserFooter.vue'

const render = (online: boolean, avatarURL?: string) => renderToString(createSSRApp(WorkspaceUserFooter, {
  role: 'MEMBER', accountID: 'self', displayName: 'Егор', online, avatarURL,
}))

describe('self account presence', () => {
  it('shows live connection presence with an initials avatar', async () => {
    const html = await render(true)
    expect(html).toContain('class="user-footer-presence"')
    expect(html).toContain('aria-label="В сети"')
    expect(html).toContain('Открыть настройки профиля')
    expect(html).toContain('Настройки аудио')
  })
  it('keeps the same presence marker for uploaded avatars', async () => {
    const html = await render(true, '/avatar/self')
    expect(html).toContain('src="/avatar/self"')
    expect(html).toContain('class="user-footer-presence"')
  })
  it('does not claim online status when the realtime connection is absent', async () => {
    expect(await render(false)).not.toContain('class="user-footer-presence"')
  })
})
