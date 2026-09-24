import { describe, expect, it, vi } from 'vitest'

import { refreshTopologyHint } from './topology_realtime'

describe('topology realtime hint', () => {
  it('refreshes topology after a channel.updated revision', async () => {
    const store = { error: null as string | null, refresh: vi.fn(async () => {}) }
    await refreshTopologyHint(store)
    expect(store.refresh).toHaveBeenCalledOnce()
  })

  it('rejects a failed ACL-protected refresh', async () => {
    const store = { error: '403', refresh: vi.fn(async () => {}) }
    await expect(refreshTopologyHint(store)).rejects.toThrow('403')
  })
})
