import { describe, expect, it, vi } from 'vitest'

import { advanceReadIfVisible, newestServerMessageId } from './direct_message_read_gate'

describe('direct-message read gate', () => {
  it('ignores optimistic rows when choosing the read cursor', () => {
    expect(newestServerMessageId([{ id: 'optimistic:a', sendStatus: 'sending' }, { id: 'server-b' }])).toBe('server-b')
    expect(newestServerMessageId([{ id: 'optimistic:a', sendStatus: 'failed' }])).toBeUndefined()
  })
  it('does not call the mutation for a hidden, unselected or empty conversation', async () => {
    const advance = vi.fn()

    await expect(advanceReadIfVisible({ activeDirectMessageId: 'dm-1', renderedDirectMessageId: 'dm-1', newestDisplayedMessageId: 'message-2', visibilityState: 'hidden' }, advance)).resolves.toBe(false)
    await expect(advanceReadIfVisible({ activeDirectMessageId: 'dm-2', renderedDirectMessageId: 'dm-1', newestDisplayedMessageId: 'message-2', visibilityState: 'visible' }, advance)).resolves.toBe(false)
    await expect(advanceReadIfVisible({ activeDirectMessageId: 'dm-1', renderedDirectMessageId: 'dm-1', newestDisplayedMessageId: undefined, visibilityState: 'visible' }, advance)).resolves.toBe(false)
    expect(advance).not.toHaveBeenCalled()
  })

  it('uses the newest displayed message only for an active visible DM', async () => {
    const advance = vi.fn().mockResolvedValue(undefined)

    await expect(advanceReadIfVisible({ activeDirectMessageId: 'dm-1', renderedDirectMessageId: 'dm-1', newestDisplayedMessageId: 'message-2', visibilityState: 'visible' }, advance)).resolves.toBe(true)
    expect(advance).toHaveBeenCalledWith('dm-1', 'message-2')
  })
})
