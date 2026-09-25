import { describe, expect, it, vi } from 'vitest'

import { createSearchContextController } from './search_context_controller'

describe('addressed search context', () => {
  it('opens a bounded page only when its first row is the requested anchor', async () => {
    const load = vi.fn().mockResolvedValue({ messages: [{ id: 'old', deleted: false }, { id: 'older', deleted: false }] })
    const context = createSearchContextController(load)
    await context.open('old')
    expect(load).toHaveBeenCalledExactlyOnceWith('old')
    expect(context.status.value).toBe('ready')
    expect(context.messages.value).toHaveLength(2)
  })

  it('explains a removed or deleted anchor without showing the stale search excerpt', async () => {
    const load = vi.fn().mockResolvedValueOnce({ messages: [{ id: 'other', deleted: false }] })
      .mockResolvedValueOnce({ messages: [{ id: 'old', deleted: true, body: '' }] })
    const context = createSearchContextController(load)
    await context.open('old')
    expect(context.status.value).toBe('unavailable')
    expect(context.messages.value).toEqual([])
    await context.open('old')
    expect(context.status.value).toBe('deleted')
    expect(context.messages.value[0]).toMatchObject({ body: '' })
  })

  it('discards an old request after a different result opens', async () => {
    let finish!: (page: { messages: { id: string; deleted: boolean }[] }) => void
    const load = vi.fn().mockImplementationOnce(() => new Promise((resolve) => { finish = resolve }))
      .mockResolvedValueOnce({ messages: [{ id: 'new', deleted: false }] })
    const context = createSearchContextController(load)
    const old = context.open('old')
    await context.open('new')
    finish({ messages: [{ id: 'old', deleted: false }] })
    await old
    expect(context.status.value).toBe('ready')
    expect(context.messages.value).toMatchObject([{ id: 'new' }])
  })
})
