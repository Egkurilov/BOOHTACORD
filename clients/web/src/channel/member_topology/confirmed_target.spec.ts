import { describe, expect, it } from 'vitest'

import { confirmedTargetIsCurrent } from './confirmed_target'
import type { ChannelTopology } from '../topology_client'

const current: ChannelTopology = {
  revision: 7,
  categories: [{ id: 'category-1', name: 'Общее', position: 0, channels: [
    { id: 'channel-1', name: 'Чат', kind: 'TEXT', position: 0, admissionClosed: false },
  ] }],
}

describe('confirmed destructive topology target', () => {
  it('accepts the same channel and revision shown in the confirmation', () => {
    expect(confirmedTargetIsCurrent(current, current.categories[0]!.channels[0]!, 7)).toBe(true)
  })

  it('rejects a changed revision even while the same target still exists', () => {
    expect(confirmedTargetIsCurrent({ ...current, revision: 8 }, current.categories[0]!.channels[0]!, 7)).toBe(false)
  })

  it('rejects a target that disappeared while the confirmation was open', () => {
    expect(confirmedTargetIsCurrent({ revision: 7, categories: [{ ...current.categories[0]!, channels: [] }] }, current.categories[0]!.channels[0]!, 7)).toBe(false)
  })

  it('rejects a channel whose name or kind changed since confirmation', () => {
    const changedChannel = { ...current.categories[0]!.channels[0]!, name: 'Новый чат' }
    expect(confirmedTargetIsCurrent({ revision: 7, categories: [{ ...current.categories[0]!, channels: [changedChannel] }] }, current.categories[0]!.channels[0]!, 7)).toBe(false)
  })

  it('rejects deleting a category that gained channels while confirmation was open', () => {
    const emptyCategory = { id: 'empty', name: 'Пустой', position: 1, channels: [] }
    const nowOccupied = { ...emptyCategory, channels: [current.categories[0]!.channels[0]!] }
    expect(confirmedTargetIsCurrent({ revision: 7, categories: [...current.categories, nowOccupied] }, emptyCategory, 7)).toBe(false)
  })
})
