import { describe, expect, it } from 'vitest'

import { VoiceVolumePreferences } from './voice_volume_preferences'

function storage() {
  const values = new Map<string, string>()
  return { getItem: (key: string) => values.get(key) ?? null, setItem: (key: string, value: string) => values.set(key, value) }
}

describe('voice volume preferences', () => {
  it('persists independent participant and screen levels for the current account only', () => {
    const local = storage()
    const owner = new VoiceVolumePreferences(local)
    const other = new VoiceVolumePreferences(local)
    owner.bind('owner-a')
    other.bind('owner-b')

    owner.setParticipant('remote-a', 175)
    owner.setScreen('remote-a', 35)

    expect(owner.participant('remote-a')).toBe(175)
    expect(owner.screen('remote-a')).toBe(35)
    expect(other.participant('remote-a')).toBe(100)
    expect(other.screen('remote-a')).toBe(100)
  })

  it('normalizes malformed or out-of-range stored values to safe defaults', () => {
    const local = storage()
    const preferences = new VoiceVolumePreferences(local)
    preferences.bind('owner-a')

    preferences.setParticipant('remote-a', 999)
    preferences.setScreen('remote-a', Number.NaN)

    expect(preferences.participant('remote-a')).toBe(200)
    expect(preferences.screen('remote-a')).toBe(100)
  })

  it('keeps the current call volume when storage fails and isolates a later account', () => {
    const blockedStorage = {
      getItem: (_key: string): string | null => { throw new Error('storage blocked') },
      setItem: (_key: string, _value: string): void => { throw new Error('storage blocked') },
    }
    const preferences = new VoiceVolumePreferences(blockedStorage)
    preferences.bind('owner-a')
    preferences.setParticipant('remote-a', 175)
    preferences.setScreen('remote-a', 35)

    expect(preferences.participant('remote-a')).toBe(175)
    expect(preferences.screen('remote-a')).toBe(35)

    preferences.bind('owner-a')
    expect(preferences.participant('remote-a')).toBe(100)

    preferences.bind('owner-b')
    expect(preferences.participant('remote-a')).toBe(100)
    expect(preferences.screen('remote-a')).toBe(100)
  })
})
