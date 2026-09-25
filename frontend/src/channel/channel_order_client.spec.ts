import { describe, expect, it, vi } from 'vitest'

import { ChannelOrderError, reorderChannels } from './channel_order_client'

describe('channel order client', () => {
  it('sends the complete order for exactly one category and its expected revision', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ revision: 14 })))
    await expect(reorderChannels('cat-a', ['voice-2', 'text-1', 'voice-1'], 13, request)).resolves.toEqual({ revision: 14 })
    expect(request).toHaveBeenCalledWith('/api/v1/admin/categories/cat-a/channels/order', {
      method: 'PUT', credentials: 'same-origin',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({ expected_revision: 13, ids: ['voice-2', 'text-1', 'voice-1'] }),
    })
  })

  it('rejects duplicate IDs and returns typed 409 without mutating caller order', async () => {
    const request = vi.fn().mockResolvedValue(new Response(null, { status: 409 }))
    const ids = ['voice-1', 'text-1']
    await expect(reorderChannels('cat-a', ids, 13, request)).rejects.toBeInstanceOf(ChannelOrderError)
    expect(ids).toEqual(['voice-1', 'text-1'])
    await expect(reorderChannels('cat-a', ['voice-1', 'voice-1'], 13, request)).rejects.toThrow('порядок')
    expect(request).toHaveBeenCalledTimes(1)
  })
})
