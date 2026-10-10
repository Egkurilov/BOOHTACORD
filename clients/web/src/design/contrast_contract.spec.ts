import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const tokens = readFileSync(new URL('./tokens.css', import.meta.url), 'utf8')

function color(name: string): string {
  const match = tokens.match(new RegExp(`--gc-${name}:\\s*(#[0-9a-fA-F]{6});`))
  if (!match) throw new Error(`Missing six-digit color token: ${name}`)
  return match[1]
}

function luminance(hex: string): number {
  const channels = [1, 3, 5].map((offset) => parseInt(hex.slice(offset, offset + 2), 16) / 255)
  const linear = channels.map((value) => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4)
  return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
}

function contrast(first: string, second: string): number {
  const values = [luminance(first), luminance(second)].sort((a, b) => b - a)
  return (values[0] + 0.05) / (values[1] + 0.05)
}

describe('GuildChat dark-theme contrast tokens', () => {
  it('keeps text pairs at 4.5:1 and control pairs at 3:1', () => {
    const textPairs = [
      ['text-primary', 'content'], ['text-primary', 'sidebar'], ['text-primary', 'surface'],
      ['text-secondary', 'content'], ['text-secondary', 'sidebar'], ['text-secondary', 'surface'],
      ['text-muted', 'content'], ['text-muted', 'sidebar'], ['text-muted', 'surface'],
      ['accent-text', 'content'], ['accent-text', 'sidebar'], ['on-accent', 'accent'],
      ['success', 'success-bg'], ['warning', 'warning-bg'], ['danger', 'danger-bg'],
      ['danger-text', 'surface'],
    ] as const
    const controlPairs = [['border-control', 'surface'], ['focus', 'content'], ['accent', 'content']] as const

    for (const [foreground, background] of textPairs) {
      expect(contrast(color(foreground), color(background)), `${foreground} on ${background}`).toBeGreaterThanOrEqual(4.5)
    }
    for (const [foreground, background] of controlPairs) {
      expect(contrast(color(foreground), color(background)), `${foreground} against ${background}`).toBeGreaterThanOrEqual(3)
    }
  })
})
