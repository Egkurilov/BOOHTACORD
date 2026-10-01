import { onBeforeUnmount, onMounted, watch, type Ref } from 'vue'

import { useAuthorDirectory } from './author_directory'
import type { OwnProfile } from './profile_client'

export function useAuthorDirectoryLifecycle(profile: Ref<OwnProfile | null>): void {
  const authors = useAuthorDirectory()
  watch(profile, (current) => { if (current) authors.acceptOwnProfile(current) }, { immediate: true })
  let timer: number | null = null
  function refresh(): void { if (document.visibilityState === 'visible') void authors.refreshKnown() }
  onMounted(() => {
    document.addEventListener('visibilitychange', refresh)
    timer = window.setInterval(refresh, 60_000)
  })
  onBeforeUnmount(() => {
    document.removeEventListener('visibilitychange', refresh)
    if (timer !== null) window.clearInterval(timer)
  })
}
