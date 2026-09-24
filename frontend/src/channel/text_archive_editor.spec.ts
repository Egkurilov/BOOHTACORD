import { describe, expect, it, vi } from 'vitest'

import { createTextArchiveEditor } from './text_archive_editor'
import type { TopologyCategory } from './topology_client'

const categories: TopologyCategory[] = [{ id: 'cat-1', name: 'Игры', position: 0, channels: [
  { id: 'text-1', name: 'Общий', kind: 'TEXT', position: 0, admissionClosed: false },
  { id: 'voice-1', name: 'Команда', kind: 'VOICE', position: 1, admissionClosed: false },
] }]

describe('TEXT archive editor', () => {
  it('does not call DELETE without explicit confirmation or for a VOICE channel', async () => {
    const request = vi.fn()
    const confirm = vi.fn().mockReturnValue(false)
    const editor = createTextArchiveEditor(() => ({ categories, revision: 7, selectedChannelId: 'text-1' }), vi.fn(), vi.fn(), confirm, request)
    await expect(editor.archive()).resolves.toBe(false)
    expect(confirm).toHaveBeenCalledWith(expect.stringContaining('История сообщений сохранится'))
    expect(request).not.toHaveBeenCalled()
    const voice = createTextArchiveEditor(() => ({ categories, revision: 7, selectedChannelId: 'voice-1' }), vi.fn(), vi.fn(), vi.fn().mockReturnValue(true), request)
    await expect(voice.archive()).resolves.toBe(false)
    expect(request).not.toHaveBeenCalled()
  })

  it('clears only the archived selection after success and refreshes topology', async () => {
    const changed = vi.fn()
    const clearSelected = vi.fn()
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: 'text-1', revision: 8 })))
    const editor = createTextArchiveEditor(() => ({ categories, revision: 7, selectedChannelId: 'text-1' }), changed, clearSelected, () => true, request)
    await expect(editor.archive()).resolves.toBe(true)
    expect(clearSelected).toHaveBeenCalledWith('text-1')
    expect(changed).toHaveBeenCalledTimes(1)
    expect(editor.needsRefresh.value).toBe(true)
    await expect(editor.archive()).resolves.toBe(false)
    expect(request).toHaveBeenCalledTimes(1)
  })

  it('retains selection on 403/409 and refreshes only after conflict', async () => {
    let revision = 7
    const changed = vi.fn()
    const clearSelected = vi.fn()
    const request = vi.fn().mockResolvedValueOnce(new Response(null, { status: 403 }))
      .mockResolvedValueOnce(new Response(null, { status: 409 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'text-1', revision: 9 })))
    const editor = createTextArchiveEditor(() => ({ categories, revision, selectedChannelId: 'text-1' }), changed, clearSelected, () => true, request)
    await expect(editor.archive()).resolves.toBe(false)
    expect(editor.error.value).toContain('прав')
    expect(changed).not.toHaveBeenCalled()
    await expect(editor.archive()).resolves.toBe(false)
    expect(editor.conflict.value).toBe(true)
    expect(changed).toHaveBeenCalledTimes(1)
    expect(clearSelected).not.toHaveBeenCalled()
    revision = 8
    editor.sync()
    await expect(editor.archive()).resolves.toBe(true)
    expect(JSON.parse(String(request.mock.calls[2][1].body))).toEqual({ expected_revision: 8, confirm_archive: true })
    expect(clearSelected).toHaveBeenCalledWith('text-1')
  })
})
