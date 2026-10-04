import { readFileSync } from 'node:fs'
import { expect, it } from 'vitest'
import { voiceAudioProfiles, defaultVoiceAudioProfile } from './generated'
import { publishOptions, selectVoiceAudioProfile, selectedVoiceAudioProfile } from './profile'

it('matches the canonical contract and preserves the approved default', () => {
  const contract = JSON.parse(readFileSync(new URL('../../../../../contracts/voice-audio-profile.json', import.meta.url), 'utf8'))
  expect(voiceAudioProfiles).toEqual(contract.profiles)
  expect(defaultVoiceAudioProfile).toBe(contract.default)
  expect(selectedVoiceAudioProfile().maxBitrate).toBe(128000)
  expect(publishOptions(selectedVoiceAudioProfile())).toEqual({ audioPreset: { maxBitrate: 128000, priority: 'high' }, forceStereo: false, dtx: true, red: true })
})
it('pins a captured profile while the next trial changes', () => {
  const pinned = selectedVoiceAudioProfile()
  selectVoiceAudioProfile('speech-64-v1')
  expect(selectedVoiceAudioProfile().maxBitrate).toBe(64000)
  expect(pinned.maxBitrate).toBe(128000)
  expect(selectVoiceAudioProfile('untrusted')).toBe(false)
  selectVoiceAudioProfile(defaultVoiceAudioProfile)
})
