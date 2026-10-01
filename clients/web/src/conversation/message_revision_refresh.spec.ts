import { describe, expect, it, vi } from 'vitest'

import { findLoadedMessage } from './message_revision_refresh'

describe('targeted loaded-message refresh', () => {
  it('finds an older loaded row across protected history pages', async () => {
    const load = vi.fn(async (before?: string) => before
      ? { messages: [{ id: 'old', revision: 2 }] }
      : { messages: [{ id: 'new', revision: 1 }], nextCursor: 'cursor-1' })
    await expect(findLoadedMessage('old', 2, load, () => true)).resolves.toMatchObject({ revision: 2 })
    expect(load).toHaveBeenNthCalledWith(1, undefined)
    expect(load).toHaveBeenNthCalledWith(2, 'cursor-1')
  })

  it('stops after navigation and rejects a repeated cursor', async () => {
    let current = true
    const load = vi.fn(async () => { current = false; return { messages: [{ id: 'old' }] } })
    await expect(findLoadedMessage('old', 1, load, () => current)).resolves.toBeNull()
    const loop = vi.fn(async () => ({ messages: [{ id: 'other' }], nextCursor: 'same' }))
    await expect(findLoadedMessage('old', 1, loop, () => true)).resolves.toBeNull()
    expect(loop).toHaveBeenCalledTimes(2)
  })
})
