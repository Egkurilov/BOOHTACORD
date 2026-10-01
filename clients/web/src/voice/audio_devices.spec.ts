import { describe, expect, it } from 'vitest'

import { listAudioDevices } from './audio_devices'

describe('audio device discovery', () => {
  it('enumerates inputs and outputs without requesting capture permission', async () => {
    const calls: unknown[][] = []
    const catalogue = {
      getLocalDevices: async (kind: 'audioinput' | 'audiooutput', permission: false) => {
        calls.push([kind, permission])
        return [{ deviceId: kind, label: '' }] as MediaDeviceInfo[]
      },
    }

    await expect(listAudioDevices(async () => catalogue)).resolves.toEqual({
      inputs: [{ id: 'audioinput', label: 'Микрофон 1' }],
      outputs: [{ id: 'audiooutput', label: 'Динамик 1' }],
    })
    expect(calls).toEqual([['audioinput', false], ['audiooutput', false]])
  })
})
