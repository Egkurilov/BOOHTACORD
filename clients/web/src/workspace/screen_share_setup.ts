import { ref } from 'vue'

import type { ScreenProfile } from '../voice/livekit_gateway'
import { readScreenProfilePreference, saveScreenProfilePreference, type ScreenSharePreferenceStorage } from '../voice/screen_profile_metadata/profile'

export function useScreenShareSetup(
  screenState: () => string,
  startScreen: (profile: ScreenProfile) => Promise<void>,
  accountId: string,
  originId = appOrigin(),
  storage = appStorage(),
) {
  const selectedScreenProfile = ref<ScreenProfile>(readScreenProfilePreference(storage, originId, accountId) ?? 'P1080_30')
  const screenShareSetupOpen = ref(false)
  function openScreenShareSetup(profile = selectedScreenProfile.value): void {
    if (screenState() === 'STARTING' || screenState() === 'STOPPING') return
    selectedScreenProfile.value = profile
    screenShareSetupOpen.value = true
  }
  function confirmScreenShare(profile: ScreenProfile): void {
    selectedScreenProfile.value = profile
    saveScreenProfilePreference(storage, originId, accountId, profile)
    screenShareSetupOpen.value = false
    void startScreen(profile)
  }
  return { confirmScreenShare, openScreenShareSetup, screenShareSetupOpen, selectedScreenProfile }
}

function appOrigin(): string {
  return typeof window === 'undefined' ? '' : window.location.origin
}

function appStorage(): ScreenSharePreferenceStorage | undefined {
  try { return typeof window === 'undefined' ? undefined : window.localStorage } catch { return undefined }
}
