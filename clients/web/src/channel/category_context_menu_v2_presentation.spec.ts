import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const component = readFileSync(new URL('./ChannelNavigation.vue', import.meta.url), 'utf8')
const styles = readFileSync(new URL('../design/design_v2_contextual_overlays.css', import.meta.url), 'utf8')

describe('Design V2 category context menu', () => {
  it('uses the handoff action icons and retains permission guarded actions', () => {
    for (const path of ['M12 5v14M5 12h14', 'M3 5h6l2 2h10v13H3V5Z', 'm16 3 5 5L8 21H3v-5L16 3ZM14 5l5 5', 'M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7M14 10v7']) expect(component).toContain(path)
    expect(component).toContain("props.permissions?.['category.delete']")
    expect(component).toContain("emit('createInCategory', categoryMenu.category)")
    expect(styles).toContain('.category-context-icon svg { width: 18px; height: 18px;')
  })
})
