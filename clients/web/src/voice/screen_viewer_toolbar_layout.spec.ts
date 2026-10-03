import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(path: string): string { return readFileSync(new URL(path, import.meta.url), 'utf8') }

describe('selected-stream toolbar layout', () => {
  it('keeps audio, pin, statistics and fullscreen controls beside the real player', () => {
    const viewer = source('./ScreenViewer.vue')
    const rail = source('./ScreenViewerRail.vue')
    const css = source('../design/design_v2_screen_viewer.css')
    expect(viewer).toContain('class="stream-quality-row"')
    expect(viewer).toContain('ScreenViewerAudioControl')
    expect(viewer).toContain('ScreenReceiverDiagnosticsPanel')
    expect(viewer).toContain('class="screen-fullscreen-button stream-tool-button"')
    expect(viewer).toContain('<ScreenViewerRail')
    expect(rail).toContain("emit('returnVoice')")
    expect(css).toContain('grid-template-rows: minmax(0, 1fr) 48px 100px')
    expect(css).toContain('grid-template-rows: minmax(0, 1fr) 56px 84px')
    expect(css).toContain('min-height: 44px;')
  })

  it('offers quality changes only to the active sender and exposes receiver statistics', () => {
    const viewer = source('./ScreenViewer.vue')
    const panel = source('./ScreenReceiverDiagnosticsPanel.vue')
    const css = source('../design/design_v2_stream_diagnostics.css')
    expect(viewer).toContain('v-if="ownScreenSharing"')
    expect(viewer).toContain('function changeQuality()')
    expect(viewer).toContain("emit('changeQuality')")
    expect(panel).toContain('aria-label="Статистика"')
    expect(panel).toContain('Нет свежих данных')
    expect(panel).toContain('Потери пакетов за 10 с')
    expect(panel).toContain('alignLeft: window.innerWidth <= 1100')
    expect(css).toContain('.stream-diagnostics-backdrop')
    expect(css).toContain('height: min(514px, 80dvh)')
  })

  it('lets mobile stream cards use the full thumbnail and scroll without a visual chevron', () => {
    const css = source('../design/design_v2_screen_viewer.css')
    expect(css).toContain('.voice-room .screen-cards .stream-option { width: 128px; min-width: 128px; height: 80px; min-height: 80px; padding: 0; }')
    expect(css).toContain('.voice-room .screen-cards .stream-option.selected { padding: 0; }')
    expect(css).toContain('.stream-card-preview { height: 50px; min-height: 50px; }')
    expect(css).toContain('.stream-card-preview .stream-avatar { align-self: start; margin-top: 14px; }')
    expect(css).toContain('.screen-cards.stream-rail.has-overflow::after { display: none; }')
    expect(css).toContain('.voice-room .workspace-header-toggle--nav, .voice-room .workspace-header-toggle--members { width: 44px; height: 44px; }')
  })
})
