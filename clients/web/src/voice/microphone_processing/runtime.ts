import { ref, shallowRef } from 'vue'
import { defaultMicrophoneSettings, MicrophonePreferences, normalizeMicrophoneSettings, type MicrophoneSettings } from './settings'
export interface MicrophoneMeter { levelDb: number; clipping: boolean; gateOpen: boolean; status: 'idle' | 'initializing' | 'active' | 'unsupported' | 'error' }
export const microphoneSettings = ref({ ...defaultMicrophoneSettings })
export const microphoneMeter = shallowRef<MicrophoneMeter>({ levelDb: -90, clipping: false, gateOpen: false, status: 'idle' })
export const microphoneSettingsError = ref<string | null>(null)
const preferences = new MicrophonePreferences()
const listeners = new Set<() => void>()
let vad = true
let accountGeneration = 0
export function microphoneAccountGeneration(): number { return accountGeneration }
function notify(): void { listeners.forEach(listener => listener()) }
export function bindMicrophoneAccount(account: string | null): void {
  accountGeneration++
  preferences.bind(account)
  microphoneSettings.value = account ? preferences.get() : { ...defaultMicrophoneSettings }
  microphoneSettingsError.value = null
  notify()
}
export function setMicrophoneSettings(settings: MicrophoneSettings): void {
  try {
    const next = normalizeMicrophoneSettings(settings)
    preferences.set(next)
    microphoneSettings.value = next
    microphoneSettingsError.value = null
    notify()
  } catch { microphoneSettingsError.value = 'Не удалось сохранить настройки микрофона.' }
}
export function setMicrophoneVad(enabled: boolean): void { vad = enabled; notify() }
export function readMicrophoneControls() { return { settings: { ...microphoneSettings.value }, vad } }
export function subscribeMicrophoneControls(listener: () => void): () => void { listeners.add(listener); return () => listeners.delete(listener) }
