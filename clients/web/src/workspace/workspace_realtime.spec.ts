import { describe, expect, it, vi } from 'vitest'

import { refreshProtectedState } from './workspace_realtime'

function stores() {
  return {
    topology: { refresh: vi.fn(async () => {}), error: null as string | null },
    messages: { channelId: 'text-1' as string | null, refresh: vi.fn(async () => {}), error: null as string | null },
    directMessages: {
      directMessageId: null as string | null,
      refreshNavigation: vi.fn(async () => {}), refreshHistory: vi.fn(async () => {}), error: null as string | null,
    },
  }
}

describe('workspace protected realtime recovery', () => {
  it('reloads topology, DM navigation and only the visible TEXT history', async () => {
    const value = stores()
    await refreshProtectedState(value)
    expect(value.topology.refresh).toHaveBeenCalledOnce()
    expect(value.directMessages.refreshNavigation).toHaveBeenCalledOnce()
    expect(value.messages.refresh).toHaveBeenCalledOnce()
    expect(value.directMessages.refreshHistory).not.toHaveBeenCalled()
  })

  it('reloads the selected DM history without fetching an inactive TEXT history', async () => {
    const value = stores()
    value.directMessages.directMessageId = 'dm-1'
    await refreshProtectedState(value)
    expect(value.messages.refresh).not.toHaveBeenCalled()
    expect(value.directMessages.refreshHistory).toHaveBeenCalledOnce()
  })

  it('rejects failed protected refresh so the realtime cursor cannot acknowledge it', async () => {
    const value = stores()
    value.topology.refresh.mockImplementation(async () => { value.topology.error = 'Нет доступа' })
    await expect(refreshProtectedState(value)).rejects.toThrow('Нет доступа')
  })
})
