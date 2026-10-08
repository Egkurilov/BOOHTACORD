import { describe, it, expect, vi } from 'vitest'
import { loadArchives, archiveHistory, changeArchive, archiveDownloadUrl, archiveSearch } from './client'
const id = '11111111-1111-4111-8111-111111111111'
describe('readonly archive client', () => {
  it('uses protected separate history path and existing message parser', async () => {
    const request = vi.fn(async (_url: string, _init: RequestInit) => Response.json({ messages: [] }))
    expect(await archiveHistory(id, 'cursor', request)).toEqual({ messages: [], nextCursor: undefined })
    expect(request.mock.calls[0]?.[0]).toContain(`/archives/text-channels/${id}/messages?before=cursor`)
    expect(request.mock.calls[0]?.[1].credentials).toBe('same-origin')
  })
  it('rejects malformed list and preserves backend conflict', async () => {
    await expect(loadArchives(undefined, async (_url: string, _init: RequestInit) => Response.json({ channels: [] }))).rejects.toThrow()
    await expect(changeArchive(id, 2, true, async () => new Response('', { status: 409 }))).rejects.toThrow('409')
  })
  it('keeps archive searches separate from global and private dialog search', async () => {
    const request = vi.fn(async (_url: string, _init: RequestInit) => Response.json({ messages: [] }))
    await archiveSearch(id, 'orbit', 'cursor', request)
    expect(request.mock.calls[0]?.[0]).toContain(`/archives/text-channels/${id}/search?query=orbit&before=cursor`)
    expect(request.mock.calls[0]?.[0]).not.toContain('direct_message_id')
  })
  it('requires positive revision and explicit archive confirmation', async () => {
    const request = vi.fn(async (_url: string, _init: RequestInit) => Response.json({ id, revision: 3 }))
    await changeArchive(id, 2, true, request)
    expect(JSON.parse(request.mock.calls[0]?.[1].body as string)).toEqual({ expected_revision: 2, confirm: true })
    await expect(changeArchive(id, 0, true, request)).rejects.toThrow()
    expect(archiveDownloadUrl(id, 'file')).toContain(`/archives/text-channels/${id}/attachments/file`)
  })
})
