import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(path: string): string { return readFileSync(new URL(path, import.meta.url), 'utf8') }

describe('selected screen receiver panel', () => {
  it('shows measured receiver values only when available and keeps unavailable RTT explicit', () => {
    const viewer = source('./ScreenViewer.vue')
    const panel = source('./ScreenReceiverDiagnosticsPanel.vue')
    const styles = source('../design/voice_viewer_reference.css')

    expect(viewer).toContain('<ScreenReceiverDiagnosticsPanel')
    expect(panel).toContain('<details class="stream-diagnostics">')
    expect(panel).toContain('Нет свежих данных')
    expect(panel).toContain('Декодировано')
    expect(panel).toContain('Нет данных от приёмника')
    expect(panel).toContain('<dt>Целевой профиль</dt><dd>Не передан источником</dd>')
    expect(panel).toContain("hasAudio ? 'Аудиодорожка есть' : 'Аудиодорожки нет'")
    expect(styles).toContain('width: min(288px, calc(100vw - 32px))')
    expect(styles).toContain('font-variant-numeric: tabular-nums')
  })
})
