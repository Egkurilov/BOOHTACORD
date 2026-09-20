import { describe, expect, it, vi } from 'vitest'

import { loadTopology, parseTopology } from './topology_client'

const topology = {
  revision: 3,
  categories: [{
    id: '5ec5bb7a-d835-47e4-8139-239acf6d3276', name: 'Игры', position: 0,
    channels: [{
      id: 'c0db3645-b84e-4df4-982c-96cd5eef9487', name: 'общий', kind: 'VOICE',
      position: 0, admission_closed: false,
    }],
  }],
}

describe('channel topology client', () => {
  it('loads the authenticated same-origin topology without inventing channels', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify(topology)))

    await expect(loadTopology(request)).resolves.toEqual({
      revision: 3,
      categories: [{
        id: '5ec5bb7a-d835-47e4-8139-239acf6d3276', name: 'Игры', position: 0,
        channels: [{
          id: 'c0db3645-b84e-4df4-982c-96cd5eef9487', name: 'общий', kind: 'VOICE',
          position: 0, admissionClosed: false,
        }],
      }],
    })
    expect(request).toHaveBeenCalledWith('/api/v1/channels', {
      credentials: 'same-origin', headers: { accept: 'application/json' },
    })
  })

  it('rejects malformed server data instead of rendering it as a channel', () => {
    expect(() => parseTopology({ revision: -1, categories: [] })).toThrow('некорректную')
  })
})
