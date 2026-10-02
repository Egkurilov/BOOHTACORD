import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const voice = readFileSync(new URL('../design/voice.css', import.meta.url), 'utf8')
const shell = readFileSync(new URL('../design/shell.css', import.meta.url), 'utf8')
const tokens = readFileSync(new URL('../design/tokens.css', import.meta.url), 'utf8')

function token(name: string): number {
  const value = tokens.match(new RegExp(`--gc-${name}:\\s*(\\d+)px;`))?.[1]
  if (!value) throw new Error(`Missing layout token: ${name}`)
  return Number(value)
}

describe('GuildChat voice participant grid', () => {
  it('fits six readable cards at 1440 CSS px and scales down at narrower breakpoints', () => {
    const rule = voice.match(/\.participant-grid, \.voice-participant-volumes \{([^}]+)\}/)?.[1] ?? ''
    const minCard = Number(rule.match(/minmax\((\d+)px,\s*1fr\)/)?.[1])
    const gapName = rule.match(/gap: var\(--gc-(space-\d+)\)/)?.[1] ?? ''
    const columns = (viewport: number, frame: string, nav: string): number => {
      const border = viewport >= 1440 ? 0 : 1
      const usable = viewport - 2 * token(frame) - 2 * border - token(nav) - 2 * token('space-6')
      const gap = token(gapName)
      return Math.floor((usable + gap) / (minCard + gap))
    }

    expect(shell).toContain('border: 1px solid var(--gc-border-subtle)')
    expect(voice).toMatch(/\.room-wrap \{[^}]*padding: var\(--gc-space-6\)/)
    expect(rule).toContain('gap: var(--gc-space-3)')
    expect(minCard).toBe(160)
    expect(columns(1440, 'layout-frame-wide', 'layout-nav-wide')).toBe(6)
    expect(columns(1280, 'layout-frame-medium', 'layout-nav-medium')).toBe(5)
    expect(columns(1024, 'layout-frame-medium', 'layout-nav-small')).toBe(4)
    const wideContent = 1440 - 2 * token('layout-frame-wide') - token('layout-nav-wide') - 2 * token('space-6')
    const wideCardWidth = (wideContent - 5 * token(gapName)) / 6
    expect(wideCardWidth).toBeGreaterThan(174)
    expect(wideCardWidth).toBeLessThan(176)
  })
})
