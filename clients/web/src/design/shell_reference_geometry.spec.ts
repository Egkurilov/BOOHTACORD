import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const tokens = readFileSync(new URL('./tokens.css', import.meta.url), 'utf8')
const shell = readFileSync(new URL('./shell.css', import.meta.url), 'utf8')

function token(name: string): number {
  const value = tokens.match(new RegExp(`--gc-${name}:\\s*(\\d+)px;`))?.[1]
  if (!value) throw new Error(`Missing layout token: ${name}`)
  return Number(value)
}

describe('1440px PNG shell geometry', () => {
  it('keeps long member identities inside the profile popover', () => {
    expect(shell).toContain('.member-popover-identity > div { min-width: 0; flex: 1 1 auto; }')
    expect(shell).toContain('-webkit-line-clamp: 2')
    expect(shell).toContain('.member-popover-identity p { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }')
  })

  it('keeps the chat and voice content at the screenshot x coordinates', () => {
    const wideRule = shell.match(/@media \(min-width: 1440px\) \{([\s\S]*?)\n\}/)?.[1] ?? ''
    const wideNav = token('layout-nav-wide')
    const wideAside = token('layout-aside-wide')
    const wideFrame = token('layout-frame-wide')

    expect([wideFrame, wideNav, wideAside]).toEqual([0, 280, 248])
    expect(1440 - 2 * wideFrame - wideNav - wideAside).toBe(912)
    expect(1440 - 2 * wideFrame - wideNav).toBe(1160)
    expect(wideRule).toContain('height: 100dvh')
    expect(wideRule).toContain('border: 0')
    expect(wideRule).toContain('border-radius: 0')
    expect(wideRule).toContain('.members { display: block; padding: var(--gc-space-6) var(--gc-space-4); }')
    expect(shell).toContain('@media (min-width: 1280px) and (max-width: 1439px)')
    expect(readFileSync(new URL('./responsive_shell.css', import.meta.url), 'utf8')).toContain('@media (min-width: 1024px) and (max-width: 1279px)')
  })
})
