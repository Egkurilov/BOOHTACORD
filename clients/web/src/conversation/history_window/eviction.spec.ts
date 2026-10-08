import { describe, expect, it } from 'vitest'

import { boundHistoryWindow } from './eviction'

const rows = Array.from({ length: 12 }, (_, index) => ({
  id: `message-${12 - index}`,
}))

describe('reversible history window', () => {
  it('keeps the visible anchor and exposes cursors for both evicted edges', () => {
    const window = boundHistoryWindow(rows, {
      limit: 6,
      anchorMessageId: 'message-7',
    })

    expect(window.messages.map(({ id }) => id)).toEqual([
      'message-10',
      'message-9',
      'message-8',
      'message-7',
      'message-6',
      'message-5',
    ])
    expect(window.olderCursor).toBe('message-5')
    expect(window.newerCursor).toBe('message-10')
  })

  it('preserves server paging availability when no rows need eviction', () => {
    const window = boundHistoryWindow(rows.slice(0, 3), {
      limit: 6,
      anchorMessageId: 'message-11',
      canPageOlder: true,
    })

    expect(window.messages).toEqual(rows.slice(0, 3))
    expect(window.olderCursor).toBe('message-10')
    expect(window.newerCursor).toBeUndefined()
  })

  it('falls back to the newest contiguous range if the anchor was removed', () => {
    const window = boundHistoryWindow(rows, {
      limit: 4,
      anchorMessageId: 'missing',
    })

    expect(window.messages.map(({ id }) => id)).toEqual([
      'message-12',
      'message-11',
      'message-10',
      'message-9',
    ])
    expect(window.olderCursor).toBe('message-9')
    expect(window.newerCursor).toBeUndefined()
  })

  it('rejects a zero or negative cache bound', () => {
    expect(() => boundHistoryWindow(rows, { limit: 0 })).toThrow(
      'History window limit must be positive.',
    )
  })
})
