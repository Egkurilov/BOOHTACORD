import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'

import ScreenReceiverDiagnosticsPanel from './ScreenReceiverDiagnosticsPanel.vue'

function source(path: string): string { return readFileSync(new URL(path, import.meta.url), 'utf8') }

describe('selected screen receiver panel', () => {
  it('shows a recent percentage with a ten-second label', async () => {
    const html = await renderToString(createSSRApp(ScreenReceiverDiagnosticsPanel, {
      actualVideoQuality: '1280 × 720 · 30 FPS', hasAudio: false, isLocal: false,
      metrics: { bitrateKbps: 500, decodedFps: 30, droppedFrames: 0, jitterMs: 2, packetsLost: 2476, packetLossPercent: 0.5 },
      sampledAt: 1000,
    }))
    expect(html).toContain('Потери пакетов за 10 с')
    expect(html).toContain('0,5 %')
    expect(html).not.toContain('>2476<')
  })

  it('shows measured receiver values only when available and keeps unavailable RTT explicit', () => {
    const viewer = source('./ScreenViewer.vue')
    const panel = source('./ScreenReceiverDiagnosticsPanel.vue')
    const styles = source('../design/voice_viewer_reference.css')

    expect(viewer).toContain('<ScreenReceiverDiagnosticsPanel')
    expect(panel).toContain('<details class="stream-diagnostics">')
    expect(panel).toContain('Нет свежих данных')
    expect(panel).toContain('Декодировано')
    expect(panel).toContain('Потери пакетов за 10 с')
    expect(panel).toContain('packetLossPercent')
    expect(panel).toContain('Нет данных от приёмника')
    expect(panel).toContain('Нет данных от источника')
    expect(panel).toContain("hasAudio ? 'Аудиодорожка есть' : 'Аудиодорожки нет'")
    expect(styles).toContain('width: min(288px, calc(100vw - 32px))')
    expect(styles).toContain('font-variant-numeric: tabular-nums')
  })
})
