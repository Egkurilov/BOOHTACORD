import { describe, expect, it, vi } from 'vitest'

import { createChannelMoveEditor } from './channel_move_editor'
import type { TopologyCategory } from './topology_client'

const categories: TopologyCategory[] = [
  { id: 'cat-a', name: 'A', position: 0, channels: [{ id: 'voice-1', name: 'Voice', kind: 'VOICE', position: 0, admissionClosed: false }] },
  { id: 'cat-b', name: 'B', position: 1, channels: [] },
]

describe('channel move editor', () => {
  it('retains the target on a stale revision and retries only after topology refresh', async () => {
    let revision = 7
    const changed = vi.fn()
    const request = vi.fn().mockResolvedValueOnce(new Response(null, { status: 409 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'voice-1', category_id: 'cat-b', position: 0, revision: 9 })))
    const editor = createChannelMoveEditor(() => ({ categories, revision, selectedChannelId: 'voice-1' }), changed, request)
    editor.sync()
    editor.setTargetCategoryId('cat-b')
    await expect(editor.move()).resolves.toBe(false)
    expect(editor.targetCategoryId.value).toBe('cat-b')
    expect(editor.conflict.value).toBe(true)
    expect(changed).toHaveBeenCalledTimes(1)
    await expect(editor.move()).resolves.toBe(false)
    expect(request).toHaveBeenCalledTimes(1)
    revision = 8
    editor.sync()
    await expect(editor.move()).resolves.toBe(true)
    expect(JSON.parse(String(request.mock.calls[1][1].body))).toEqual({ category_id: 'cat-b', expected_revision: 8 })
    expect(categories[0].channels[0].kind).toBe('VOICE')
  })

  it('rejects a same-category move before making a request', async () => {
    const request = vi.fn()
    const editor = createChannelMoveEditor(() => ({ categories, revision: 7, selectedChannelId: 'voice-1' }), vi.fn(), request)
    editor.sync()
    editor.setTargetCategoryId('cat-a')
    expect(editor.canMove()).toBe(false)
    await expect(editor.move()).resolves.toBe(false)
    expect(request).not.toHaveBeenCalled()
  })
})
