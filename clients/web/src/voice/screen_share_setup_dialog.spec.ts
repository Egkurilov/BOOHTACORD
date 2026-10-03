import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

import ScreenShareSetupDialog from './ScreenShareSetupDialog.vue'

describe('screen-share setup dialog', () => {
  it('offers the shared resolution and frame-rate choices before browser capture', async () => {
    const html = await renderToString(createSSRApp(ScreenShareSetupDialog, {
      initialProfile: 'P1080_30',
    }))

    expect(html).toContain('Демонстрация экрана')
    expect(html).toContain('Разрешение')
    expect(html).toContain('Частота кадров')
    expect(html).toContain('720p')
    expect(html).toContain('1080p')
    expect(html).toContain('1440p')
    expect(html).toContain('15 FPS')
    expect(html).toContain('30 FPS')
    expect(html).toContain('60 FPS')
    expect([...html.matchAll(/<span>(\d{3,4}p)<\/span>/g)].map((match) => match[1]))
      .toEqual(['720p', '1080p', '1440p'])
    expect([...html.matchAll(/<span>(15|30|60) FPS<\/span>/g)].map((match) => match[1]))
      .toEqual(['15', '30', '60'])
    expect(html).toContain('браузер покажет системный запрос')
    expect(html).toContain('Начать трансляцию')
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

    expect(html).toContain('<input checked type="radio" name="screen-share-resolution" value="1440">')
    expect(html).toContain('<input checked type="radio" name="screen-share-frame-rate" value="60">')
  })

  it('shows the current stream quality editor only for an updating sender', async () => {
    const html = await renderToString(createSSRApp(ScreenShareSetupDialog, { initialProfile: 'P1440_60', updating: true }))
    expect(html).toContain('Качество трансляции')
    expect(html).toContain('Изменения применятся к текущему показу.')
    expect(html).toContain('При ухудшении сети качество может временно снижаться.')
    expect(html).toContain('<circle cx="12" cy="12" r="9"></circle>')
    expect(html).toContain('Применить')
    expect(html).not.toContain('браузер покажет системный запрос')
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
    expect(updating).toContain('background: var(--gc-surface)')
    expect(updating).toContain('background: var(--gc-accent)')
    expect(updating).toContain('background: var(--gc-sidebar)')
    expect(updating).toContain('font-weight: 600; letter-spacing: -.2px')
    expect(updating).toContain('font-weight: 500;')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__footer button { min-height: 44px; }')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__footer button { min-height: 36px; font-weight: 500; }')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__close svg { width: 20px; height: 20px; stroke-width: 1.8; }')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__header { position: relative;')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__close { position: absolute; top: 24px; right: 24px; width: 36px; height: 36px; }')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__close { top: 26px; right: 20px; width: 44px; height: 44px; }')
  })
})
