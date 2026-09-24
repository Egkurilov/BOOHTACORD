import { describe, expect, it, vi } from 'vitest'

import { advanceTextReadIfVisible, newestServerTextMessageId } from './text_read_gate'

describe('TEXT read gate', () => {
  it('ignores optimistic messages when choosing a cursor', () => {
    expect(newestServerTextMessageId([{ id: 'optimistic:a', sendStatus: 'sending' }, { id: 'server-b' }])).toBe('server-b')
    expect(newestServerTextMessageId([{ id: 'optimistic:a', sendStatus: 'failed' }])).toBeUndefined()
  })

  it('does not mark background, another channel or empty history as read', async () => {
    const advance = vi.fn()
    const base = { activeChannelId: 'text-1', renderedChannelId: 'text-1', newestDisplayedMessageId: 'message-2' }
    await expect(advanceTextReadIfVisible({ ...base, visibilityState: 'hidden' }, advance)).resolves.toBe(false)
    await expect(advanceTextReadIfVisible({ ...base, activeChannelId: 'text-2', visibilityState: 'visible' }, advance)).resolves.toBe(false)
    await expect(advanceTextReadIfVisible({ ...base, newestDisplayedMessageId: undefined, visibilityState: 'visible' }, advance)).resolves.toBe(false)
    expect(advance).not.toHaveBeenCalled()
  })

  it('advances only the currently rendered visible channel', async () => {
    const advance = vi.fn().mockResolvedValue(undefined)
    await expect(advanceTextReadIfVisible({ activeChannelId: 'text-1', renderedChannelId: 'text-1', newestDisplayedMessageId: 'message-2', visibilityState: 'visible' }, advance)).resolves.toBe(true)
    expect(advance).toHaveBeenCalledWith('text-1', 'message-2')
  })
})
