import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(path: string): string { return readFileSync(new URL(path, import.meta.url), 'utf8') }

describe('selected-stream toolbar layout', () => {
  it('keeps quality and game volume below the stage, with secondary actions in the return bar', () => {
    const viewer = source('./ScreenViewer.vue')
    const row = viewer.slice(viewer.indexOf('class="stream-quality-row"'), viewer.indexOf('class="screen-rail-section"'))
    const footer = viewer.slice(viewer.indexOf('class="stream-voice-return"'))

    expect(row).toContain('stream-target')
    expect(row).toContain('stream-actual')
    expect(row).toContain('ScreenReceiverDiagnosticsPanel')
    expect(row).toContain('ScreenViewerAudioControl')
    expect(source('./ScreenViewerAudioControl.vue')).toContain('volume-control')
    expect(row).not.toContain('screen-window-toggle')
    expect(footer).toContain('v-if="selectedStream || expanded" class="screen-window-toggle')
    expect(footer).toContain('К участникам')
  })

  it('keeps quality legible and gives mobile diagnostics a visible label', () => {
    const viewer = source('./ScreenViewer.vue')
    const css = source('../design/voice_viewer_reference.css')

    const panel = source('./ScreenReceiverDiagnosticsPanel.vue')
    expect(panel).toContain('Нет свежих данных')
    expect(panel).toContain(':title="status"')
    expect(panel).toContain('<span>Статистика</span>')
    expect(css).toMatch(/\.stream-quality \{[^}]*display: flex;[^}]*justify-content: space-between/)
    expect(css).toMatch(/\.stream-diagnostics > summary \{[^}]*min-height: 36px;/)
    expect(css).toContain('.stream-diagnostics-panel { position: fixed;')
    expect(panel).toContain('alignLeft: window.innerWidth <= 1100')
    expect(css).toContain('@media (max-width: 600px)')
    expect(css).toContain('.stream-diagnostics { flex: 1 1 100%; }')
    expect(css).toContain('.stream-voice-return {')
  })
})
