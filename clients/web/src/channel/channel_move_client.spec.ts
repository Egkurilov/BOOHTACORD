import { describe, expect, it, vi } from 'vitest'

import { ChannelMoveError, moveChannel } from './channel_move_client'

describe('channel move client', () => {
  it('moves a channel to a category under the expected topology revision', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: 'voice-1', category_id: 'cat-b', position: 2, revision: 8 })))
    await expect(moveChannel('voice-1', 'cat-b', 7, request)).resolves.toEqual({ id: 'voice-1', categoryId: 'cat-b', position: 2, revision: 8 })
    expect(request).toHaveBeenCalledWith('/api/v1/admin/channels/voice-1/category', {
      method: 'PATCH', credentials: 'same-origin',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({ category_id: 'cat-b', expected_revision: 7 }),
    })
  })

  it('returns typed 409 and rejects a mismatched successful response', async () => {
    const conflict = vi.fn().mockResolvedValue(new Response(null, { status: 409 }))
    await expect(moveChannel('text-1', 'cat-b', 7, conflict)).rejects.toBeInstanceOf(ChannelMoveError)
    await expect(moveChannel('text-1', 'cat-b', 7, conflict)).rejects.toMatchObject({ status: 409 })
    const mismatched = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: 'other', category_id: 'cat-b', position: 0, revision: 8 })))
    await expect(moveChannel('text-1', 'cat-b', 7, mismatched)).rejects.toThrow('некоррект')
  })
})
