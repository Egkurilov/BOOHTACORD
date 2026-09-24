import { describe, expect, it, vi } from 'vitest'

import { createChannelRenameEditor } from './channel_rename_editor'
import type { TopologyCategory } from './topology_client'

const categories: TopologyCategory[] = [{ id: 'cat-1', name: 'Игры', position: 0, channels: [
  { id: 'voice-1', name: 'Голосовой', kind: 'VOICE', position: 0, admissionClosed: false },
  { id: 'text-1', name: 'Общий', kind: 'TEXT', position: 1, admissionClosed: false },
] }]

describe('channel rename editor', () => {
  it('keeps the draft after 409 and retries with refreshed topology revision', async () => {
    let revision = 5
    const changed = vi.fn()
    const request = vi.fn().mockResolvedValueOnce(new Response(null, { status: 409 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'voice-1', name: 'Новый голосовой', revision: 7 })))
    const editor = createChannelRenameEditor(() => ({ categories, revision, selectedChannelId: 'voice-1' }), changed, request)
    editor.sync()
    editor.setDraft('Новый голосовой')
    await expect(editor.rename()).resolves.toBe(false)
    expect(editor.draft.value).toBe('Новый голосовой')
    expect(editor.conflict.value).toBe(true)
    expect(changed).toHaveBeenCalledTimes(1)
    await expect(editor.rename()).resolves.toBe(false)
    revision = 6
    editor.sync()
    await expect(editor.rename()).resolves.toBe(true)
    expect(JSON.parse(String(request.mock.calls[1][1].body))).toEqual({ name: 'Новый голосовой', expected_revision: 6 })
  })

  it('validates name and restores an untouched draft when the selected channel changes', async () => {
    let selectedChannelId = 'voice-1'
    const request = vi.fn()
    const editor = createChannelRenameEditor(() => ({ categories, revision: 5, selectedChannelId }), vi.fn(), request)
    editor.sync()
    expect(editor.draft.value).toBe('Голосовой')
    selectedChannelId = 'text-1'
    editor.sync()
    expect(editor.draft.value).toBe('Общий')
    editor.setDraft('  ')
    await expect(editor.rename()).resolves.toBe(false)
    expect(editor.error.value).toContain('имя')
    expect(request).not.toHaveBeenCalled()
  })
})
