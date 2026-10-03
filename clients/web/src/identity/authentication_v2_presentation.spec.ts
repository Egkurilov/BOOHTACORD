import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const presentation = readFileSync(new URL('../design/design_v2_authentication_presentation.css', import.meta.url), 'utf8')

describe('Design V2 authentication presentation', () => {
  it('uses the handoff radial background on desktop and mobile', () => {
    expect(presentation).toContain('radial-gradient(ellipse at 50% 10%, #21203D 0, transparent 48%), var(--gc-canvas)')
  })
})
