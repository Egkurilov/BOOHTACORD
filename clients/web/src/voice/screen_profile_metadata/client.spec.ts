import { describe, expect, it, vi } from 'vitest'
import { updateScreenProfileDescriptor } from './client'
import type { ScreenShareDescriptorV1 } from './types'

const descriptor: ScreenShareDescriptorV1 = {
  schema_version: 1, scope: { origin_id: 'https://voice.example.test', account_id: '', room_id: 'voice:room', media_session_id: 'session', publication_generation: 1, operation_revision: 2 },
  mode: 'text', publisher_state: 'sharing', viewer_state: 'idle', requested_profile_id: 'P1080_30',
  effective_profile: { capture: { max_width: 1920, max_height: 1080, max_fps: 30 }, encoding: { codec: null, layers: [{ rid: null, width: 1920, height: 1080, max_fps: 30, max_bitrate_bps: 2000000, scale_down_by: 1, active: true }] } },
  layer_topology: 'single-layer', profile_revision: 1, capabilities: { live_update: true, republish_without_recapture: true, simulcast: false }, reason_codes: ['user-request'],
}

describe('updateScreenProfileDescriptor', () => {
  it('writes the descriptor through the authenticated same-origin server route', async () => {
    const request = vi.fn(async () => new Response(null, { status: 204 }))
    await updateScreenProfileDescriptor('lease/id', descriptor, request)
    expect(request).toHaveBeenCalledWith(expect.stringContaining('/voice/leases/lease%2Fid/screen-profile/v1'), expect.objectContaining({
      method: 'PUT', mode: 'same-origin', credentials: 'same-origin', cache: 'no-store', body: JSON.stringify(descriptor),
    }))
  })

  it('surfaces server rejection without claiming metadata was updated', async () => {
    await expect(updateScreenProfileDescriptor('lease', descriptor, async () => new Response(null, { status: 409 }))).rejects.toThrow()
  })

  it('retries an uncertain server response with the same operation revision and body', async () => {
    const request = vi.fn().mockResolvedValueOnce(new Response(null, { status: 503 })).mockResolvedValueOnce(new Response(null, { status: 204 }))
    await updateScreenProfileDescriptor('lease', descriptor, request)
    expect(request).toHaveBeenCalledTimes(2)
    expect(request.mock.calls[0]?.[1]?.body).toBe(request.mock.calls[1]?.[1]?.body)
  })
})
