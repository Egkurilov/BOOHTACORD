import { describe, expect, it, vi } from 'vitest'

import { createVoiceCloseEditor } from './voice_close_editor'
import type { TopologyCategory } from './topology_client'

const voice = { id: 'voice-1', name: 'Команда', kind: 'VOICE' as const, position: 0, admissionClosed: false }
const categories: TopologyCategory[] = [{ id: 'cat-1', name: 'Игры', position: 0, channels: [voice] }]

describe('VOICE close admission editor', () => {
  it('waits for asynchronous confirmation before closing admission', async () => {
    let decide!: (value: boolean) => void
    const confirmation = new Promise<boolean>((resolve) => { decide = resolve })
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: 'voice-1', revision: 8, revoked_leases: 0 })))
    const editor = createVoiceCloseEditor(() => ({ categories, revision: 7, selectedChannelId: 'voice-1' }),
      vi.fn(), () => confirmation, request)
    const action = editor.close()
    expect(request).not.toHaveBeenCalled()
    decide(true)
    await expect(action).resolves.toBe(true)
    expect(JSON.parse(String(request.mock.calls[0][1].body))).toEqual({ expected_revision: 7 })
  })

  it('keeps an asynchronously cancelled close out of the API', async () => {
    const request = vi.fn()
    const editor = createVoiceCloseEditor(() => ({ categories, revision: 7, selectedChannelId: 'voice-1' }),
      vi.fn(), async () => false, request)
    await expect(editor.close()).resolves.toBe(false)
    expect(request).not.toHaveBeenCalled()
  })

  it('requires confirmation and rejects TEXT or already closed channels', async () => {
    const request = vi.fn()
    const confirm = vi.fn().mockReturnValue(false)
    const editor = createVoiceCloseEditor(() => ({ categories, revision: 7, selectedChannelId: 'voice-1' }), vi.fn(), confirm, request)
    await expect(editor.close()).resolves.toBe(false)
    expect(confirm).toHaveBeenCalledWith(expect.stringContaining('отзыв media-доступа'), expect.any(Function))
    expect(request).not.toHaveBeenCalled()
    const closed = [{ ...categories[0]!, channels: [{ ...voice, admissionClosed: true }] }]
    const closedEditor = createVoiceCloseEditor(() => ({ categories: closed, revision: 8, selectedChannelId: 'voice-1' }), vi.fn(), () => true, request)
    await expect(closedEditor.close()).resolves.toBe(false)
  })

  it('does not close admission when account or confirmed target changes during the prompt', async () => {
    let accountId = 'account-1'
    let revision = 7
    let currentCategories = categories
    const request = vi.fn()
    const editor = createVoiceCloseEditor(
      () => ({ accountId, categories: currentCategories, revision, selectedChannelId: 'voice-1' }),
      vi.fn(), async (_message, stillCurrent) => {
        accountId = 'account-2'
        expect(stillCurrent()).toBe(false)
        return true
      }, request,
    )

    await expect(editor.close()).resolves.toBe(false)
    expect(request).not.toHaveBeenCalled()

    accountId = 'account-1'
    revision = 7
    currentCategories = categories
    const staleTarget = createVoiceCloseEditor(
      () => ({ accountId, categories: currentCategories, revision, selectedChannelId: 'voice-1' }),
      vi.fn(), async (_message, stillCurrent) => {
        revision = 8
        currentCategories = [{ ...categories[0]!, channels: [] }]
        expect(stillCurrent()).toBe(false)
        return true
      }, request,
    )
    await expect(staleTarget.close()).resolves.toBe(false)
    expect(request).not.toHaveBeenCalled()
  })

  it('keeps SFU pending after success even with zero logical leases, then finalizes only when server topology omits the channel', async () => {
    let revision = 7
    let current = categories
    const changed = vi.fn()
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: 'voice-1', revision: 8, revoked_leases: 0 })))
    const editor = createVoiceCloseEditor(() => ({ categories: current, revision, selectedChannelId: 'voice-1' }), changed, () => true, request)
    await expect(editor.close()).resolves.toBe(true)
    expect(editor.phase.value).toBe('pending')
    expect(editor.status.value).toContain('SFU')
    expect(changed).toHaveBeenCalledTimes(1)
    revision = 8
    current = [{ ...categories[0]!, channels: [{ ...voice, admissionClosed: true }] }]
    editor.sync()
    expect(editor.phase.value).toBe('pending')
    expect(editor.needsRefresh.value).toBe(false)
    revision = 9
    current = [{ ...categories[0]!, channels: [] }]
    editor.sync()
    expect(editor.phase.value).toBe('finalized')
    expect(editor.status.value).toContain('сервером')
  })

  it('retains the selected channel after 409 and allows retry only after a new revision', async () => {
    let revision = 7
    const changed = vi.fn()
    const request = vi.fn().mockResolvedValueOnce(new Response(null, { status: 409 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'voice-1', revision: 9, revoked_leases: 1 })))
    const editor = createVoiceCloseEditor(() => ({ categories, revision, selectedChannelId: 'voice-1' }), changed, () => true, request)
    await expect(editor.close()).resolves.toBe(false)
    expect(editor.needsRefresh.value).toBe(true)
    expect(changed).toHaveBeenCalledTimes(1)
    await expect(editor.close()).resolves.toBe(false)
    revision = 8
    editor.sync()
    await expect(editor.close()).resolves.toBe(true)
    expect(JSON.parse(String(request.mock.calls[1][1].body))).toEqual({ expected_revision: 8 })
  })
})
