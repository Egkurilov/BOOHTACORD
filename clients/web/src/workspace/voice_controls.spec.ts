import { describe, expect, it, vi } from 'vitest'

const audioSettings = { loadProcessing: vi.fn().mockResolvedValue(undefined), select: vi.fn() }
const voiceConnection = { active: null, join: vi.fn().mockResolvedValue(undefined), setAudioProcessing: vi.fn(), leave: vi.fn(), startScreen: vi.fn() }

vi.mock('../channel/topology_store', () => ({ useTopologyStore: () => ({ topology: null }) }))
vi.mock('../voice/audio_settings_store', () => ({ useAudioSettingsStore: () => audioSettings }))
vi.mock('../voice/activation_store', () => ({ useVoiceActivationStore: () => ({ stop: vi.fn() }) }))
vi.mock('../voice/connection_store', () => ({ useVoiceConnectionStore: () => voiceConnection }))
vi.mock('../voice/navigation_store', () => ({ useVoiceNavigationStore: () => ({ clearActiveVoice: vi.fn(), selectedSurface: { kind: 'NONE' } }) }))

import { useWorkspaceVoiceControls } from './voice_controls'

describe('workspace voice controls', () => {
  it('loads account audio-processing settings before joining voice', async () => {
    const controls = useWorkspaceVoiceControls()

    await controls.joinVoice('voice-1')

    expect(audioSettings.loadProcessing).toHaveBeenCalledWith(voiceConnection.setAudioProcessing)
    expect(audioSettings.loadProcessing.mock.invocationCallOrder[0]).toBeLessThan(voiceConnection.join.mock.invocationCallOrder[0])
  })
})
