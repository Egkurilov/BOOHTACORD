import { describe, expect, it, vi } from 'vitest'

import { createChannelOrderEditor } from './channel_order_editor'
import type { TopologyCategory } from './topology_client'

const category = (id: string, channels: string[]): TopologyCategory => ({
  id, name: id, position: 0, channels: channels.map((channelId, position) => ({ id: channelId, name: channelId, kind: 'VOICE', position, admissionClosed: false })),
})

describe('channel order editor', () => {
  it('submits all IDs of the selected category and never includes another category', async () => {
    const categories = [category('cat-a', ['voice-a', 'text-a', 'voice-b']), category('cat-b', ['other'])]
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ revision: 8 })))
    const editor = createChannelOrderEditor(() => ({ categories, revision: 7, selectedCategoryId: 'cat-a', selectedChannelId: 'text-a' }), vi.fn(), request)
    await expect(editor.move(-1)).resolves.toBe(true)
    expect(JSON.parse(String(request.mock.calls[0][1].body))).toEqual({ expected_revision: 7, ids: ['text-a', 'voice-a', 'voice-b'] })
    expect(request.mock.calls[0][0]).toContain('/categories/cat-a/channels/order')
    expect(categories[0].channels.map(({ id }) => id)).toEqual(['voice-a', 'text-a', 'voice-b'])
  })

  it('refreshes after 409 and retries with the new revision while retaining order', async () => {
    let revision = 7
    const categories = [category('cat-a', ['voice-a', 'voice-b'])]
    const changed = vi.fn()
    const request = vi.fn().mockResolvedValueOnce(new Response(null, { status: 409 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ revision: 9 })))
    const editor = createChannelOrderEditor(() => ({ categories, revision, selectedCategoryId: 'cat-a', selectedChannelId: 'voice-b' }), changed, request)
    await expect(editor.move(-1)).resolves.toBe(false)
    expect(editor.conflict.value).toBe(true)
    expect(editor.canMove(-1)).toBe(false)
    expect(categories[0].channels.map(({ id }) => id)).toEqual(['voice-a', 'voice-b'])
    expect(changed).toHaveBeenCalledTimes(1)
    revision = 8
    editor.sync()
    await expect(editor.move(-1)).resolves.toBe(true)
    expect(JSON.parse(String(request.mock.calls[1][1].body))).toEqual({ expected_revision: 8, ids: ['voice-b', 'voice-a'] })
  })
})
