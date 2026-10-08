import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

import ScreenShareSetupDialog from './ScreenShareSetupDialog.vue'
import ScreenDiagnosticsPanel from './ScreenDiagnosticsPanel.vue'

describe('screen-share setup dialog', () => {
  it('offers motion/text scenarios and ceiling choices before browser capture', async () => {
    const html = await renderToString(createSSRApp(ScreenShareSetupDialog, {
      initialProfile: 'P1080_30',
    }))

    expect(html).toContain('Демонстрация экрана')
    expect(html).toContain('Плавность — игры и видео')
    expect(html).toContain('Текст — документы и код')
    expect(html).toContain('Максимальное разрешение')
    expect(html).toContain('Частота кадров для текста')
    expect(html).toContain('720p')
    expect(html).toContain('1080p')
    expect(html).toContain('1440p')
    expect(html).toContain('15 FPS')
    expect(html).toContain('30 FPS')
    expect(html).not.toContain('60 FPS')
    expect([...html.matchAll(/<span>(\d{3,4}p)<\/span>/g)].map((match) => match[1]))
      .toEqual(['720p', '1080p', '1440p'])
    expect([...html.matchAll(/<span>(15|30|60) FPS<\/span>/g)].map((match) => match[1]))
      .toEqual(['15', '30'])
    expect(html).toContain('браузер покажет системный запрос')
    expect(html).toContain('Суммарный лимит двух слоёв')
    expect(html).toContain('не гарантированный сетевой расход')
    expect(html).toContain('Начать трансляцию')
  })

  it('keeps motion mode at 60 FPS and gates a new 1440p60 choice', async () => {
    const html = await renderToString(createSSRApp(ScreenShareSetupDialog, { initialProfile: 'P1080_60' }))
    expect(html).toContain('<legend>Частота кадров для плавности</legend>')
    expect([...html.matchAll(/<span>(15|30|60) FPS<\/span>/g)].map((match) => match[1])).toEqual(['60'])
    expect(html).toMatch(/<input[^>]*disabled[^>]*value="1440"[^>]*>/)
    expect(html).toContain('1440p60 пока недоступно без подтверждённой policy')
  })

  it('opens the dialog from both the room action and persistent voice dock', () => {
    const workspace = readFileSync(new URL('../workspace/WorkspaceApp.vue', import.meta.url), 'utf8')
    const pane = readFileSync(new URL('../conversation/ConversationPane.vue', import.meta.url), 'utf8')

    expect(workspace).toContain('<ScreenShareSetupDialog')
    expect(workspace).toContain('@start-screen="openScreenShareSetup"')
    expect(workspace).toContain('@start="confirmScreenShare"')
    expect(pane).toContain('@start-screen="emit(\'startScreen\', $event)"')
    expect(pane).toContain('@change-quality="emit(\'startScreen\', screenProfile ?? selectedScreenProfile)"')
    expect(pane).not.toContain('Целевой профиль<select')
  })

  it('restores the profile selected before the dialog was opened', async () => {
    const html = await renderToString(createSSRApp(ScreenShareSetupDialog, {
      initialProfile: 'P1440_60',
    }))

    expect(html).toMatch(/<input[^>]*checked[^>]*name="screen-share-resolution" value="1440"[^>]*>/)
    expect(html).toMatch(/<input[^>]*checked[^>]*name="screen-share-frame-rate" value="60"[^>]*>/)
  })

  it('shows the current stream quality editor only for an updating sender', async () => {
    const html = await renderToString(createSSRApp(ScreenShareSetupDialog, { initialProfile: 'P1440_60', updating: true }))
    expect(html).toMatch(/<section class="screen-share-quality" aria-labelledby="screen-share-quality-title">/)
    expect(html).toMatch(/<h3[^>]*id="screen-share-quality-title"/)
    expect(html).toContain('Качество трансляции')
    expect(html).toContain('Изменения применятся к текущему показу.')
    expect(html).toContain('При ухудшении сети качество может временно снижаться.')
    expect(html).toContain('<circle cx="12" cy="12" r="9"></circle>')
    expect(html).toContain('Применить')
    expect(html).not.toContain('браузер покажет системный запрос')
  })

  it('labels pre-picker support separately from tracks actually received after selection', async () => {
    const setup = await renderToString(createSSRApp(ScreenShareSetupDialog, { initialProfile: 'P1080_30' }))
    expect(setup).toContain('Поддержка до выбора источника')
    expect(setup).toContain('Звук определяется после выбора источника')
    expect(setup).toContain('выбранный источник может не передать аудио')
    expect(setup).not.toContain('игровой звук поддерживается')

    const diagnostics = await renderToString(createSSRApp(ScreenDiagnosticsPanel, {
      profile: 'P1080_30',
      diagnostics: { audioTrack: 'ABSENT', connectionQuality: 'GOOD', measured: null, source: 'ACTIVE' },
    }))
    expect(diagnostics).toContain('Фактически полученные дорожки')
    expect(diagnostics).toContain('Видео: есть')
    expect(diagnostics).toContain('Аудио: нет')
    expect(diagnostics).toContain('Голос остаётся доступен без аудиодорожки экрана')
  })

  it('keeps the dialog styling on shared tokens and adapts quality rows on mobile', () => {
    const styles = readFileSync(new URL('../design/screen_share_setup.css', import.meta.url), 'utf8')
    const imports = readFileSync(new URL('../style.css', import.meta.url), 'utf8')

    expect(imports).toContain("@import './design/screen_share_setup.css';")
    expect(styles).toContain('width: min(560px, calc(100vw - 40px))')
    expect(styles).toContain('var(--gc-sidebar)')
    expect(styles).toContain('@media (max-width: 600px)')
    expect(styles).toContain('grid-template-columns: minmax(0, 1fr)')
    const updating = readFileSync(new URL('../design/design_v2_screen_quality.css', import.meta.url), 'utf8')
    expect(updating).toContain('.screen-share-setup-dialog--updating::backdrop { background: var(--gc-overlay); backdrop-filter: none; }')
    expect(updating).toContain('background: var(--gc-surface)')
    expect(updating).toContain('background: var(--gc-accent)')
    expect(updating).toContain('background: var(--gc-sidebar)')
    expect(updating).toContain('font-weight: 600; letter-spacing: -.2px')
    expect(updating).toContain('font-weight: 500;')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__footer button { min-height: 44px; flex: 1; }')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__footer button { min-height: 36px; padding: 0 14px; font-size: 14px; font-weight: 500; }')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__close svg { width: 20px; height: 20px; stroke-width: 1.8; }')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__header { position: relative;')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__close { position: absolute; top: 24px; right: 24px; width: 36px; height: 36px; }')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__close { top: 26px; right: 20px; width: 44px; height: 44px; }')
  })
})
