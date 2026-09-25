import { describe, expect, it, vi } from 'vitest'

import { TextArchiveError, archiveTextChannel } from './text_archive_client'

describe('TEXT archive client', () => {
  it('sends explicit confirmation with the expected revision to the administrator DELETE route', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: 'text-1', revision: 9 })))
    await expect(archiveTextChannel('text-1', 8, request)).resolves.toEqual({ id: 'text-1', revision: 9 })
    expect(request).toHaveBeenCalledWith('/api/v1/admin/channels/text-1', {
      method: 'DELETE', credentials: 'same-origin',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({ expected_revision: 8, confirm_archive: true }),
    })
  })

  it('distinguishes forbidden and stale responses and rejects malformed success', async () => {
    const forbidden = vi.fn().mockResolvedValue(new Response(null, { status: 403 }))
    const stale = vi.fn().mockResolvedValue(new Response(null, { status: 409 }))
    await expect(archiveTextChannel('text-1', 8, forbidden)).rejects.toMatchObject({ status: 403 })
    await expect(archiveTextChannel('text-1', 8, stale)).rejects.toBeInstanceOf(TextArchiveError)
    const malformed = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: 'voice-1', revision: 9 })))
    await expect(archiveTextChannel('text-1', 8, malformed)).rejects.toThrow('некоррект')
  })
})
