import { describe, expect, it, vi } from 'vitest'

import { ChannelRenameError, renameChannel } from './channel_rename_client'

describe('channel rename client', () => {
  it('renames TEXT or VOICE through the administrator endpoint without changing kind', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: 'voice-1', name: 'Команда', revision: 12 })))
    await expect(renameChannel('voice-1', 'Команда', 11, request)).resolves.toEqual({ id: 'voice-1', name: 'Команда', revision: 12 })
    expect(request).toHaveBeenCalledWith('/api/v1/admin/channels/voice-1', {
      method: 'PATCH', credentials: 'same-origin',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({ name: 'Команда', expected_revision: 11 }),
    })
  })

  it('reports a typed conflict and rejects malformed success responses', async () => {
    const conflict = vi.fn().mockResolvedValue(new Response(null, { status: 409 }))
    await expect(renameChannel('text-1', 'Новое', 7, conflict)).rejects.toMatchObject({ status: 409 })
    await expect(renameChannel('text-1', 'Новое', 7, conflict)).rejects.toBeInstanceOf(ChannelRenameError)
    const malformed = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: 'text-1', name: 'Новое', revision: 0 })))
    await expect(renameChannel('text-1', 'Новое', 7, malformed)).rejects.toThrow('некоррект')
  })
})
