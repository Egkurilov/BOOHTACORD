import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const css = readFileSync(new URL('../design/conversation.css', import.meta.url), 'utf8')

describe('reference chat geometry', () => {
  it('aligns desktop and narrow message content after the avatar', () => {
    expect(css).toMatch(/\.messages \{[^}]*padding: var\(--gc-space-6\) var\(--gc-space-6\)/)
    expect(css).toMatch(/\.message-row \{[^}]*gap: var\(--gc-space-3\)/)
    expect(css).toContain('.messages { padding: var(--gc-space-5) var(--gc-space-4); }')
  })

  it('keeps the published attachment compact without clipping narrow layouts', () => {
    expect(css).toMatch(/\.text-message-attachments \.attachment-card \{[^}]*width: min\(100%, 340px\); min-height: 62px/)
    expect(css).toContain('.text-message-attachments > li { min-width: 0; }')
  })
})
