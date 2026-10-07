import { describe, expect, it, vi } from 'vitest'
import { LatestScreenPreviewUploader } from './uploader'

const lease = '11111111-1111-4111-8111-111111111111'
const generation = '22222222-2222-4222-8222-222222222222'
const jpeg = (marker = 1) => new Uint8Array([0xff, 0xd8, marker, 0xff, 0xd9])
const begun = () => Response.json({ schema_version: 1, generation_id: generation })
function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((done) => { resolve = done })
  return { promise, resolve }
}

describe('screen preview uploader shutdown', () => {
  it('bounds a hung begin and invalidates a generation returned after stop', async () => {
    const pending = deferred<Response>(), methods: string[] = []
    let beginSignal: AbortSignal | undefined
    const request = vi.fn(async (_url: string, init: RequestInit) => {
      methods.push(init.method!)
      if (init.method === 'POST') { beginSignal = init.signal!; return pending.promise }
      return new Response(null, { status: 204 })
    })
    const uploader = new LatestScreenPreviewUploader(request)
    const starting = uploader.start(lease)
    vi.useFakeTimers()
    try {
      const stopping = uploader.stop()
      expect(beginSignal?.aborted).toBe(true)
      await vi.advanceTimersByTimeAsync(300)
      await expect(stopping).resolves.toBeUndefined()
      pending.resolve(begun())
      await starting
      expect(methods).toEqual(['POST', 'DELETE'])
    } finally { vi.useRealTimers() }
  })

  it('aborts a hung upload, drops queued frames, and bounds leave', async () => {
    const pending = deferred<Response>(), methods: string[] = []
    let uploadSignal: AbortSignal | undefined
    const request = vi.fn(async (_url: string, init: RequestInit) => {
      methods.push(init.method!)
      if (init.method === 'POST') return begun()
      if (init.method === 'PUT') { uploadSignal = init.signal!; return pending.promise }
      return new Response(null, { status: 204 })
    })
    const uploader = new LatestScreenPreviewUploader(request)
    await uploader.start(lease)
    uploader.offer(jpeg(1)); uploader.offer(jpeg(2)); uploader.offer(jpeg(3))
    vi.useFakeTimers()
    try {
      const stopping = uploader.stop()
      expect(uploadSignal?.aborted).toBe(true)
      await vi.advanceTimersByTimeAsync(300)
      await expect(stopping).resolves.toBeUndefined()
      expect(methods).toEqual(['POST', 'PUT', 'DELETE'])
    } finally { vi.useRealTimers() }
  })

  it('keeps only the latest queued frame while an upload is active', async () => {
    const first = deferred<Response>(), firstStarted = deferred<void>(), latestStarted = deferred<void>()
    const markers: number[] = []
    const request = vi.fn(async (_url: string, init: RequestInit) => {
      if (init.method === 'POST') return begun()
      if (init.method === 'PUT') {
        markers.push((init.body as Uint8Array)[2])
        if (markers.length === 1) { firstStarted.resolve(); return first.promise }
        latestStarted.resolve()
      }
      return new Response(null, { status: 204 })
    })
    const uploader = new LatestScreenPreviewUploader(request)
    await uploader.start(lease)
    uploader.offer(jpeg(1)); await firstStarted.promise
    uploader.offer(jpeg(2)); uploader.offer(jpeg(3))
    first.resolve(new Response(null, { status: 204 }))
    await latestStarted.promise
    await uploader.stop()
    expect(markers).toEqual([1, 3])
  })

  it('aborts a hung invalidation and returns from stop within its bound', async () => {
    const pending = deferred<Response>()
    let deleteSignal: AbortSignal | undefined
    const request = vi.fn(async (_url: string, init: RequestInit) => {
      if (init.method === 'POST') return begun()
      deleteSignal = init.signal!
      return pending.promise
    })
    const uploader = new LatestScreenPreviewUploader(request)
    await uploader.start(lease)
    vi.useFakeTimers()
    try {
      const stopping = uploader.stop()
      await vi.advanceTimersByTimeAsync(300)
      await expect(stopping).resolves.toBeUndefined()
      expect(deleteSignal?.aborted).toBe(true)
    } finally { vi.useRealTimers() }
  })
})
