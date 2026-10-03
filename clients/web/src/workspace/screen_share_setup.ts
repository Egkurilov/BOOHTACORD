import { ref } from 'vue'

import type { ScreenProfile } from '../voice/livekit_gateway'

export function useScreenShareSetup(screenState: () => string, startScreen: (profile: ScreenProfile) => Promise<void>) {
  const selectedScreenProfile = ref<ScreenProfile>('P1080_30')
  const screenShareSetupOpen = ref(false)
  function openScreenShareSetup(profile = selectedScreenProfile.value): void {
    if (screenState() === 'STARTING' || screenState() === 'STOPPING') return
    selectedScreenProfile.value = profile
    screenShareSetupOpen.value = true
  }
  function confirmScreenShare(profile: ScreenProfile): void {
    selectedScreenProfile.value = profile
    screenShareSetupOpen.value = false
    void startScreen(profile)
  }
  return { confirmScreenShare, openScreenShareSetup, screenShareSetupOpen, selectedScreenProfile }
}
