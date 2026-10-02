import { describe, expect, it, vi } from 'vitest'

import { refreshDirectMessageHint } from './direct_message_realtime'

function store(active: string | null) {
  return { directMessageId: active, error: null as string | null, refreshNavigation: vi.fn(async () => {}), refreshHistory: vi.fn(async () => {}) }
}

describe('private DM realtime hints', () => {
  it('updates the other participant badge without opening an unrelated conversation', async () => {
    const value = store('dm-other')
    await refreshDirectMessageHint(value, 'dm-changed')
    expect(value.refreshNavigation).toHaveBeenCalledOnce()
    expect(value.refreshHistory).not.toHaveBeenCalled()
  })

  it('refreshes the active DM history for create, edit or delete hints', async () => {
    const value = store('dm-changed')
    await refreshDirectMessageHint(value, 'dm-changed')
    expect(value.refreshNavigation).toHaveBeenCalledOnce()
    expect(value.refreshHistory).toHaveBeenCalledOnce()
  })

  it('does not acknowledge a hint if its protected navigation refresh failed', async () => {
    const value = store('dm-changed')
    value.refreshNavigation.mockImplementation(async () => { value.error = '403' })
    await expect(refreshDirectMessageHint(value, 'dm-changed')).rejects.toThrow('403')
    expect(value.refreshHistory).not.toHaveBeenCalled()
  })
})
