import { defaultVoiceAudioProfile, voiceAudioProfiles } from './generated'
export type VoiceAudioProfile = typeof voiceAudioProfiles[number]
let selected: VoiceAudioProfile = voiceAudioProfiles.find(({ id }) => id === defaultVoiceAudioProfile)!
export function selectedVoiceAudioProfile(): VoiceAudioProfile { return selected }
// Deliberately session-local, never changes an already-created room.
export function selectVoiceAudioProfile(id: string): boolean {
  const profile = voiceAudioProfiles.find((profile) => profile.id === id)
  if (!profile) return false
  selected = profile
  return true
}
export function publishOptions(profile: VoiceAudioProfile) {
  return { audioPreset: { maxBitrate: profile.maxBitrate, priority: profile.priority }, forceStereo: profile.forceStereo, dtx: profile.dtx, red: profile.red }
}
