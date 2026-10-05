import { afterEach, expect, it, vi } from 'vitest'
vi.mock('/brand.png', () => ({ default: '/brand.png' }))
import { createSSRApp } from 'vue'
import { renderToString } from '@vue/server-renderer'
import AuthenticationLanding from '../../identity/AuthenticationLanding.vue'
import { guildProfile } from './state'
afterEach(() => guildProfile.reset())
it('renders the loaded guild name in both brand and authentication introduction', async () => {
  guildProfile.name.value = 'Автономная гильдия'
  const html = await renderToString(createSSRApp(AuthenticationLanding))
  expect(html).toContain('Войдите в «Автономная гильдия».')
  expect(html).not.toContain('Войдите в «Моя гильдия».')
})
it('escapes the public name in the authentication introduction', async () => {
  guildProfile.name.value = '<Guild & Co>'
  const html = await renderToString(createSSRApp(AuthenticationLanding))
  expect(html).toContain('Войдите в «&lt;Guild &amp; Co&gt;».')
})
