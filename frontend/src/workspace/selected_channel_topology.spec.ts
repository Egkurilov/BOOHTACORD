import { createPinia, setActivePinia } from 'pinia'
import { describe, expect, it, vi } from 'vitest'

vi.mock('../voice/audio_settings_store', () => ({ useAudioSettingsStore: () => ({}) }))
vi.mock('../voice/activation_store', () => ({ useVoiceActivationStore: () => ({}) }))
vi.mock('../voice/connection_store', () => ({ useVoiceConnectionStore: () => ({ active: null }) }))

import { useTopologyStore } from '../channel/topology_store'
import { useWorkspaceVoiceControls } from './voice_controls'

describe('selected channel topology', () => {
  it('updates the selected channel title after a refreshed rename without changing its kind', () => {
    setActivePinia(createPinia())
    const topology = useTopologyStore()
    const channel = { id: 'channel-1', name: 'Старое', kind: 'VOICE' as const, position: 0, admissionClosed: false }
    topology.topology = { revision: 7, categories: [{ id: 'cat-1', name: 'Игры', position: 0, channels: [channel] }] }
    const controls = useWorkspaceVoiceControls()
    controls.selectChannel(channel)
    expect(controls.selectedChannel.value?.name).toBe('Старое')
    topology.topology = { revision: 8, categories: [{ id: 'cat-1', name: 'Игры', position: 0, channels: [{ ...channel, name: 'Новое' }] }] }
    expect(controls.selectedChannel.value).toMatchObject({ id: 'channel-1', name: 'Новое', kind: 'VOICE' })
  })
})
