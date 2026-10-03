import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const component = readFileSync(new URL('./ChannelTopologyActions.vue', import.meta.url), 'utf8')
const styles = readFileSync(new URL('../../design/design_v2_overlays.css', import.meta.url), 'utf8')
const presentation = readFileSync(new URL('../../design/design_v2_topology_dialog.css', import.meta.url), 'utf8')

describe('Design V2 topology creation dialog', () => {
  it('labels channel and category creation while keeping server mutation handlers', () => {
    for (const text of ['Создать канал', 'Создать раздел', 'Название канала', 'Название раздела', 'Раздел', 'Отмена']) expect(component).toContain(text)
    expect(component).toContain('createMemberChannel(categoryId.value, name.value, kind.value, requestId)')
    expect(component).toContain('createMemberCategory(name.value, requestId)')
    expect(component).toContain('props.permissions')
    expect(component).toContain('@keydown.esc.prevent="close()"')
    expect(component).toContain('@keydown="containTab"')
    expect(component).toContain('opener.value?.focus()')
  })

  it('sets the handoff dialog dimensions for desktop and mobile viewports', () => {
    expect(styles).toContain('height: 513px;')
    expect(styles).toContain('height: min(530px, calc(100dvh - 32px));')
  })

  it('offers channel kinds as a permission-aware segmented control and orders the form like R08/R09', () => {
    expect(component).toContain('class="topology-kind-selector"')
    expect(component).toContain('class="topology-dialog-description"')
    expect(component).toContain('class="topology-dialog-fields"')
    expect(component).toContain('class="topology-dialog-actions"')
    expect(component).toContain('permittedKinds()')
    expect(presentation).toContain('.topology-dialog { display: flex;')
    expect(presentation).toContain('margin-top: auto; border-top:')
  })
})
