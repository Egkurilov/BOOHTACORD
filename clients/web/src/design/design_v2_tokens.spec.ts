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

  it('maps the complete normative spacing, type, and motion scales', () => {
    const expected: Record<string, string> = {
      'space-0': '0px', 'space-1': '4px', 'space-2': '8px', 'space-3': '12px',
      'space-4': '16px', 'space-5': '20px', 'space-6': '24px', 'space-8': '32px',
      'space-10': '40px', 'space-12': '48px', 'space-16': '64px',
      'radius-xs': '4px', 'radius-sm': '6px', 'radius-md': '8px',
      'radius-lg': '12px', 'radius-shell': '16px', 'radius-full': '999px',
      'text-caption': '12px', 'line-caption': '16px',
      'text-body': '14px', 'line-body': '20px',
      'text-message': '15px', 'line-message': '22px',
      'text-title': '16px', 'line-title': '24px',
      'text-section': '20px', 'line-section': '28px',
      'text-page': '24px', 'line-page': '32px',
      'weight-regular': '400', 'weight-medium': '500',
      'weight-semibold': '600', 'weight-bold': '700',
      'duration-fast': '120ms', 'duration-base': '180ms',
    }
    for (const [name, value] of Object.entries(expected)) expect(cssValue(name), name).toBe(value)
    expect(cssValue('font-family')).toContain('Inter')
  })
})
