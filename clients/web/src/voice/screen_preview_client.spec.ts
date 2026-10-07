import { describe, expect, it, vi } from 'vitest'
import { apiBaseUrl } from '../config/runtime'
import { beginScreenPreview, readScreenPreview, uploadScreenPreview, type ScreenPreviewHint, type ScreenPreviewRequest } from './screen_preview_client'
import { LatestScreenPreviewReader } from './screen_preview_reader'
import { LatestScreenPreviewUploader } from './screen_preview_uploader'

const lease = '11111111-1111-4111-8111-111111111111'
const generation = '22222222-2222-4222-8222-222222222222'
const hint: ScreenPreviewHint = { leaseId: lease, generationId: generation, revision: 1 }
const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xd9])

describe('private screen preview client', () => {
  it('mints generations through same-origin no-store requests', async () => {
    const request = vi.fn(async () => Response.json({ schema_version: 1, generation_id: generation }))
    await expect(beginScreenPreview(lease, request)).resolves.toBe(generation)
    expect(request).toHaveBeenCalledWith(`${apiBaseUrl}/voice/leases/${lease}/screen-previews/v1`, expect.objectContaining({ method: 'POST', credentials: 'same-origin', cache: 'no-store' }))
  })

  it('uploads bounded JPEGs with monotonic revision metadata only', async () => {
    const request = vi.fn<ScreenPreviewRequest>(async () => new Response(null, { status: 204 }))
    await uploadScreenPreview(lease, generation, 7, jpeg, request)
    const init = request.mock.calls[0]![1]
    expect(init.headers).toMatchObject({ 'content-type': 'image/jpeg', 'X-Screen-Preview-Revision': '7' })
    expect(init.cache).toBe('no-store')
  })

  it('reads protected JPEG bytes and honors no-update responses', async () => {
    const frame = new Response(jpeg, { headers: { 'content-type': 'image/jpeg', 'X-Screen-Preview-Revision': '2' } })
    await expect(readScreenPreview(hint, 0, vi.fn(async () => frame))).resolves.toMatchObject({ revision: 2, bytes: jpeg })
    await expect(readScreenPreview(hint, 2, vi.fn(async () => new Response(null, { status: 204 })))).resolves.toBeNull()
  })

  it('coalesces hints while one protected read is in flight', async () => {
    let finish!: (response: Response) => void
    const request = vi.fn().mockImplementationOnce(() => new Promise<Response>(resolve => { finish = resolve }))
      .mockResolvedValueOnce(new Response(jpeg, { headers: { 'content-type': 'image/jpeg', 'X-Screen-Preview-Revision': '2' } }))
    const applied: number[] = []
    const reader = new LatestScreenPreviewReader({ apply: (_hint, bytes) => applied.push(bytes.length), clear: vi.fn() }, request)
    reader.accept(hint)
    reader.accept({ ...hint, revision: 2 })
    finish(new Response(jpeg, { headers: { 'content-type': 'image/jpeg', 'X-Screen-Preview-Revision': '1' } }))
    await vi.waitFor(() => expect(request).toHaveBeenCalledTimes(2))
    expect(applied).toEqual([4])
    expect(request).toHaveBeenCalledTimes(2)
    reader.clear()
  })

  it('uploads only the newest queued frame while bounding concurrency', async () => {
    let finishFirst!: () => void
    let firstStarted!: () => void
    let secondStarted!: () => void
    const firstRequest = new Promise<void>(resolve => { finishFirst = resolve })
    const firstSeen = new Promise<void>(resolve => { firstStarted = resolve })
    const secondSeen = new Promise<void>(resolve => { secondStarted = resolve })
    const uploaded: number[] = []
    let uploadCount = 0
    const request: ScreenPreviewRequest = async (_input, init) => {
      if (init.method === 'POST') return Response.json({ schema_version: 1, generation_id: generation })
      if (init.method === 'DELETE') return new Response(null, { status: 204 })
      uploaded.push((init.body as Uint8Array)[2]!)
      uploadCount++
      if (uploadCount === 1) { firstStarted(); await firstRequest }
      if (uploadCount === 2) secondStarted()
      return new Response(null, { status: 204 })
    }
    const uploader = new LatestScreenPreviewUploader(request)
    await uploader.start(lease)
    const frame = (marker: number) => new Uint8Array([0xff, 0xd8, marker, 0xff, 0xd9])
    uploader.offer(frame(1))
    await firstSeen
    uploader.offer(frame(2))
    uploader.offer(frame(3))
    finishFirst()
    await secondSeen
    await uploader.stop()
    expect(uploaded).toEqual([1, 3])
  })
})
