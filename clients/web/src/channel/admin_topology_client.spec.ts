import { describe, expect, it, vi } from 'vitest'

import { createCategory, createChannel } from './admin_topology_client'

describe('administrator topology client', () => {
  it('posts a category through the authenticated same-origin administrator endpoint', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      id: 'category-1', name: 'POC', position: 2, revision: 7,
    }), { status: 201 }))

    await expect(createCategory({ name: 'POC' }, request)).resolves.toEqual({
      id: 'category-1', name: 'POC', position: 2, revision: 7,
    })
    expect(request).toHaveBeenCalledWith('/api/v1/admin/categories', {
      method: 'POST',
      credentials: 'same-origin',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({ name: 'POC' }),
    })
  })

  it('posts the immutable channel kind to the selected category', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      id: 'channel-1', category_id: 'category-1', name: 'game-audio-poc', kind: 'VOICE', position: 0, revision: 8,
    }), { status: 201 }))

    await expect(createChannel('category-1', { name: 'game-audio-poc', kind: 'VOICE' }, request)).resolves.toEqual({
      id: 'channel-1', categoryId: 'category-1', name: 'game-audio-poc', kind: 'VOICE', position: 0, revision: 8,
    })
    expect(request).toHaveBeenCalledWith('/api/v1/admin/categories/category-1/channels', {
      method: 'POST',
      credentials: 'same-origin',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({ name: 'game-audio-poc', kind: 'VOICE' }),
    })
  })

  it('rejects malformed category and channel responses rather than trusting them', async () => {
    const request = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'category-1', name: 'POC', position: -1, revision: 7 }), { status: 201 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'channel-1', category_id: 'category-1', name: 'общий', kind: 'CAMERA', position: 0, revision: 8 }), { status: 201 }))

    await expect(createCategory({ name: 'POC' }, request)).rejects.toThrow('некорректные')
    await expect(createChannel('category-1', { name: 'общий', kind: 'TEXT' }, request)).rejects.toThrow('некорректные')
  })

  it('accepts 80 emoji in a channel name and rejects the 81st before transport', async () => {
    const name = '😀'.repeat(80)
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      id: 'channel-1', category_id: 'category-1', name, kind: 'TEXT', position: 0, revision: 8,
    }), { status: 201 }))
    await createChannel('category-1', { name, kind: 'TEXT' }, request)
    await expect(createChannel('category-1', { name: `${name}😀`, kind: 'TEXT' }, request)).rejects.toThrow('80')
    expect(request).toHaveBeenCalledOnce()
  })
})
