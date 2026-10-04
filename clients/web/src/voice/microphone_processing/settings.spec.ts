import { describe, expect, it } from 'vitest'
import { normalizeMicrophoneSettings, MicrophonePreferences } from './settings'

describe('local microphone settings', () => {
  it('migrates missing/non-finite data and bounds numeric inputs', () => {
    expect(normalizeMicrophoneSettings({ vadThresholdDb: NaN, microphoneGainPercent: '200' })).toEqual({ vadThresholdDb: -50, microphoneGainPercent: 100 })
    expect(normalizeMicrophoneSettings({ vadThresholdDb: -200, microphoneGainPercent: 999 })).toEqual({ vadThresholdDb: -70, microphoneGainPercent: 200 })
  })
  it('isolates accounts and restores the stored manual gain', () => {
    const values = new Map<string, string>()
    const prefs = new MicrophonePreferences({ getItem: key => values.get(key) ?? null, setItem: (key, value) => { values.set(key, value) } })
    prefs.bind('one'); prefs.set({ vadThresholdDb: -44, microphoneGainPercent: 180 })
    prefs.bind('two'); expect(prefs.get().microphoneGainPercent).toBe(100)
    prefs.bind('one'); expect(prefs.get()).toEqual({ vadThresholdDb: -44, microphoneGainPercent: 180 })
  })
})
