import { describe, expect, it, vi } from 'vitest'

import { bindLiveKitScreenPreview } from './capture'

describe('LiveKit private screen preview lifecycle', () => {
  it('waits for old generation deletion before binding a changed lease', async () => {
    const leaseA = '11111111-1111-4111-8111-111111111111'
    const leaseB = '33333333-3333-4333-8333-333333333333'
    const generations = [
      '22222222-2222-4222-8222-222222222222',
      '44444444-4444-4444-8444-444444444444',
    ]
    let finishDelete!: () => void
    let deleteStarted!: () => void
    const deleting = new Promise<void>(resolve => { finishDelete = resolve })
    const deleted = new Promise<void>(resolve => { deleteStarted = resolve })
    let begins = 0
    const request = vi.fn(async (_input: string, init: RequestInit) => {
      if (init.method === 'POST') {
        const generation = generations[begins++]!
        return Response.json({ schema_version: 1, generation_id: generation })
      }
      if (init.method === 'DELETE' && begins === 1) {
        deleteStarted()
        await deleting
      }
      return new Response(null, { status: 204 })
    })
    const video = {
      readyState: 0, videoWidth: 0, videoHeight: 0,
      play: vi.fn().mockResolvedValue(undefined), pause: vi.fn(),
    } as unknown as HTMLVideoElement
    vi.stubGlobal('document', { createElement: vi.fn(() => video) })
    vi.stubGlobal('fetch', request)
    const track = { attach: vi.fn(), detach: vi.fn() }
    const localParticipant = {
      identity: 'local-lease', metadata: '',
      getTrackPublication: vi.fn(() => ({ source: 'screen', videoTrack: track })),
    }
    const room = {
      on: vi.fn(), localParticipant, remoteParticipants: new Map(),
    }
    const viewer = { viewer: { setThumbnail: vi.fn(), removeThumbnail: vi.fn() } }
    const preview = bindLiveKitScreenPreview(room, viewer, {
      trackPublished: 'published', trackUnpublished: 'unpublished', disconnected: 'disconnected',
    }, 'screen')

    try {
      await preview.bindLease(leaseA)
      const rebinding = preview.bindLease(leaseB)
      await deleted
      expect(begins).toBe(1)
      finishDelete()
      await rebinding
      expect(begins).toBe(2)
      expect(request.mock.calls.map(([input, init]) => [init.method, input])).toEqual([
        ['POST', expect.stringContaining(leaseA)],
        ['DELETE', expect.stringContaining(leaseA)],
        ['POST', expect.stringContaining(leaseB)],
      ])
    } finally {
      await preview.stop()
      vi.unstubAllGlobals()
    }
  })
})
