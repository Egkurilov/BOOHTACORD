import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const tokens = readFileSync(new URL('./tokens.css', import.meta.url), 'utf8')
const foundation = readFileSync(new URL('./foundation.css', import.meta.url), 'utf8')

function cssValue(name: string): string {
  return tokens.match(new RegExp(`--gc-${name}:\\s*([^;]+);`))?.[1].trim() ?? ''
}

describe('BOOHTACORD Design V2 shared tokens', () => {
  it('uses the handoff colors for shared surfaces and actions', () => {
    expect(cssValue('canvas')).toBe('#0B0D12')
    expect(cssValue('sidebar')).toBe('#11131A')
    expect(cssValue('content')).toBe('#171A22')
    expect(cssValue('surface')).toBe('#1A1D26')
    expect(cssValue('surface-raised')).toBe('#222631')
    expect(cssValue('accent')).toBe('#5865F2')
    expect(cssValue('accent-hover')).toBe('#4752C4')
    expect(cssValue('danger-solid')).toBe('#B91C1C')
    expect(cssValue('focus')).toBe('#B4A4FF')
    expect(cssValue('brand-accent')).toBe('#7C3AED')
    expect(cssValue('voice')).toBe('#06B6D4')
    expect(cssValue('stream')).toBe('#EC4899')
    expect(cssValue('success')).toBe('#22C55E')
    expect(cssValue('warning')).toBe('#F59E0B')
    expect(cssValue('danger')).toBe('#EF4444')
    expect(cssValue('accent-text')).toBe('#ACAEFF')
    expect(cssValue('overlay')).toBe('rgba(4, 6, 10, 0.76)')
  })

  it('uses the 64 px header, 36 px desktop channel rows, and 112 px voice dock', () => {
    expect(cssValue('layout-header')).toBe('64px')
    expect(cssValue('layout-row-channel')).toBe('36px')
    expect(cssValue('layout-user-footer')).toBe('64px')
    expect(cssValue('layout-voice-dock')).toBe('112px')
    expect(cssValue('layout-header-mobile')).toBe('56px')
    expect(cssValue('layout-dialog')).toBe('480px')
    expect(cssValue('layout-settings-max')).toBe('880px')
    expect(cssValue('size-field')).toBe('44px')
    expect(cssValue('size-touch')).toBe('44px')
    expect(cssValue('layout-aside-wide')).toBe('248px')
    expect(cssValue('layout-nav-wide')).toBe('280px')
    expect(cssValue('layout-voice-dock')).toBe('112px')
    expect(cssValue('space-16')).toBe('64px')
    expect(cssValue('radius-shell')).toBe('16px')
    expect(cssValue('z-base')).toBe('0')
    expect(cssValue('z-dock')).toBe('20')
    expect(cssValue('z-menu')).toBe('40')
    expect(cssValue('z-drawer')).toBe('50')
    expect(cssValue('z-modal')).toBe('60')
    expect(cssValue('z-tooltip')).toBe('70')
    expect(cssValue('z-toast')).toBe('80')
  })

  it('keeps common controls keyboard-visible and respects reduced motion', () => {
    expect(foundation).toContain(':focus-visible')
    expect(foundation).toContain('prefers-reduced-motion: reduce')
  })
})
