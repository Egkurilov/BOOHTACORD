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
    expect(pane).toContain('@click="emit(\'startScreen\', selectedScreenProfile)"')
    expect(pane).not.toContain('Целевой профиль<select')
  })

  it('restores the profile selected before the dialog was opened', async () => {
    const html = await renderToString(createSSRApp(ScreenShareSetupDialog, {
      initialProfile: 'P1440_60',
    }))

    expect(html).toContain('<input checked type="radio" name="screen-share-resolution" value="1440">')
    expect(html).toContain('<input checked type="radio" name="screen-share-frame-rate" value="60">')
  })

  it('keeps the dialog styling on shared tokens and adapts quality rows on mobile', () => {
    const styles = readFileSync(new URL('../design/screen_share_setup.css', import.meta.url), 'utf8')
    const imports = readFileSync(new URL('../style.css', import.meta.url), 'utf8')

    expect(imports).toContain("@import './design/screen_share_setup.css';")
    expect(styles).toContain('width: min(560px, calc(100vw - 40px))')
    expect(styles).toContain('var(--gc-sidebar)')
    expect(styles).toContain('@media (max-width: 600px)')
    expect(styles).toContain('grid-template-columns: minmax(0, 1fr)')
  })
})
