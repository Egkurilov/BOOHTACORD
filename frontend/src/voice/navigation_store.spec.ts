import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useVoiceNavigationStore } from './navigation_store'

describe('voice navigation state', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('keeps a confirmed voice room active when another channel screen is selected', () => {
    const store = useVoiceNavigationStore()

    store.confirmVoiceConnected('voice-1')
    store.selectText('text-1')

    expect(store.activeVoiceChannelId).toBe('voice-1')
    expect(store.selectedSurface).toEqual({ kind: 'TEXT', channelId: 'text-1' })
  })

  it('uses DM as the selected surface without changing an active voice connection', () => {
    const store = useVoiceNavigationStore()

    store.confirmVoiceConnected('voice-1')
    store.selectDirectMessage('dm-1')

    expect(store.selectedSurface).toEqual({ kind: 'DM', directMessageId: 'dm-1' })
    expect(store.activeVoiceChannelId).toBe('voice-1')
  })
})
