import { describe, expect, it, vi } from 'vitest'

import { listAdminScreenMetrics } from './admin_media_client'

describe('administrator screen metrics', () => {
  it('parses only bounded anonymous sample fields', async () => {
    const request = vi.fn(async (..._args: Parameters<typeof fetch>) => new Response(JSON.stringify({ samples: [{
      report: { platform: 'ios_web', direction: 'receiver', state: 'playing', frame_width: 540, frame_height: 1170, decoded_fps: 30, presented_fps: 26.5, account_id: 'secret' },
      sampled_at_utc: '2026-09-26T13:00:00Z',
    }] }), { status: 200 }))
    const result = await listAdminScreenMetrics(request)
    expect(result).toEqual([{ platform: 'ios_web', direction: 'receiver', state: 'playing', frame_width: 540, frame_height: 1170, decoded_fps: 30, presented_fps: 26.5, sampled_at_utc: '2026-09-26T13:00:00Z' }])
    expect(JSON.stringify(result)).not.toContain('secret')
    expect(request.mock.calls[0]?.[0]).toBe('/api/v1/admin/screen-metrics')
  })

  it('rejects a malformed response instead of inventing measurements', async () => {
    const request = vi.fn(async () => new Response(JSON.stringify({ samples: [{ report: { platform: 'ios_web', direction: 'receiver', state: 'playing', decoded_fps: '30' }, sampled_at_utc: '2026-09-26T13:00:00Z' }] }), { status: 200 }))
    await expect(listAdminScreenMetrics(request)).rejects.toThrow('Некорректные показатели')
  })

  it('rejects an incomplete or out-of-range frame size', async () => {
    const request = vi.fn(async () => new Response(JSON.stringify({ samples: [{
      report: { platform: 'android_native', direction: 'sender', state: 'playing', frame_width: 540 },
      sampled_at_utc: '2026-09-26T13:00:00Z',
    }] }), { status: 200 }))
    await expect(listAdminScreenMetrics(request)).rejects.toThrow('Некорректные показатели')
  })
})
