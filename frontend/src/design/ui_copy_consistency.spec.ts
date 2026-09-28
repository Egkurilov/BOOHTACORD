import { existsSync, readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(relativePath: string): string {
  return readFileSync(new URL(relativePath, import.meta.url), 'utf8')
}

describe('working UI name and media wording', () => {
  it('uses one working product name on the tab, login page and notifications', () => {
    const title = source('../../index.html').match(/<title>([^<]+)<\/title>/)?.[1]
    expect(title).toBe('Voice Platform')
    expect(source('../identity/AuthenticationLanding.vue')).toContain(`<h1 id="authentication-title">${title}</h1>`)
    expect(source('../notification/notification_delivery.ts')).toContain(`runtime.show('${title}'`)
  })

  it('uses the supplied artwork as the browser favicon', () => {
    const html = source('../../index.html')
    const favicon = new URL('../../public/favicon.png', import.meta.url)
    expect(html).toContain('<link rel="icon" type="image/png" href="/favicon.png" />')
    expect(existsSync(favicon)).toBe(true)
  })

  it('does not claim audible game sound or voices from a published track', () => {
    const viewer = source('../voice/ScreenViewer.vue')
    const dock = source('../voice/VoiceDock.vue')
    expect(viewer).not.toMatch(/Звук игры|Игровой звук|Голоса участников остаются слышны/)
    expect(dock).not.toContain('демонстрация экрана продолжается')
    expect(viewer).toContain('ScreenViewerAudioControl')
    expect(source('../voice/ScreenViewerAudioControl.vue')).toContain('Громкость аудиодорожки')
  })
})
