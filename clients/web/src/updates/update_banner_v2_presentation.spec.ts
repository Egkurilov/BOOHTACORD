import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const component = readFileSync(new URL('./UpdateBanner.vue', import.meta.url), 'utf8')
const styles = readFileSync(new URL('../design/design_v2_contextual_overlays.css', import.meta.url), 'utf8')

describe('Design V2 update banner', () => {
  it('uses the handoff refresh and dismiss outlines while keeping live actions', () => {
    expect(component).toContain('M20 7v5h-5M4 17v-5h5M5 7a8 8 0 0 1 13-2l2 2M4 17l2 2a8 8 0 0 0 13-2')
    expect(component).toContain('m6 6 12 12M18 6 6 18')
    expect(component).toContain('@click="updates.apply"')
    expect(component).toContain('@click="updates.later"')
    expect(styles).toContain('.update-banner .update-summary svg { width: 18px; height: 18px;')
    expect(styles).toContain('border-bottom: 1px solid #57519B;')
  })
})
