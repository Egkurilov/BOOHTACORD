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
    expect(component).toContain('@keydown.esc.stop.prevent="close()"')
    expect(component).toContain('@keydown.stop="containTab"')
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
    expect(presentation).toContain('.topology-dialog-header { position: relative; min-height: 36px; margin: 30px 20px 0; }')
    expect(presentation).toContain('.topology-dialog-header button { position: absolute; top: -2px; right: 0; width: 44px; height: 44px; }')
  })

  it('uses the handoff speaker outline for a voice channel', () => {
    expect(component).toContain('M15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14')
  })

  it('hides background message controls while the creation dialog owns the screen', () => {
    expect(presentation).toContain('body:has(.topology-dialog-backdrop) .message-actions-toggle { visibility: hidden; }')
  })

  it('uses the handoff sidebar surface for channel and category fields', () => {
    expect(presentation).toContain('color: var(--gc-text-primary); background: var(--gc-sidebar); font-size: 14px;')
  })
})
