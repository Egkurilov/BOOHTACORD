import { ref } from 'vue'
import { loadOwnProfile, type OwnProfile } from './profile_client'

export function useCurrentProfile() {
  const profile = ref<OwnProfile | null>(null)
  const profileLoading = ref(true)
  const profileError = ref<string | null>(null)

  async function refreshProfile(): Promise<void> {
    profileLoading.value = true
    try {
      profile.value = await loadOwnProfile()
      profileError.value = null
    } catch (cause) {
      profileError.value = cause instanceof Error ? cause.message : 'Не удалось загрузить профиль.'
    } finally {
      profileLoading.value = false
    }
  }

  function setProfile(next: OwnProfile): void {
    profile.value = next
  }

  return { profile, profileError, profileLoading, refreshProfile, setProfile }
}
