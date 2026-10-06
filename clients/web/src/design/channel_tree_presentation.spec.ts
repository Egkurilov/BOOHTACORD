import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const channelTree = readFileSync(new URL('./design_v2_channel_tree.css', import.meta.url), 'utf8')

describe('channel tree presentation', () => {
  it('keeps channel actions visible and gives category headings a compact highlighted group row', () => {
    expect(channelTree).toMatch(/\.channel-navigation \.channel-actions-button \{[^}]*opacity: 1;/)
    expect(channelTree).toMatch(/\.channel-navigation \.channel-category h2 \{[^}]*margin: 6px 0 2px;/)
    expect(channelTree).toMatch(/\.channel-navigation \.channel-category h2 \{[^}]*background: var\(--gc-surface\);/)
    expect(channelTree).toContain('.channel-navigation .channel-category + .channel-category { margin-top: 0; }')
  })
})
