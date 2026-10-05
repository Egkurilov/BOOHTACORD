import { ref } from 'vue'
import { loadGuildProfile, type GuildProfile } from './client'
export function createGuildProfileState(read: () => Promise<GuildProfile> = loadGuildProfile) {
  const name = ref('BOOHTACORD'), revision = ref(0), loading = ref(false)
  let generation = 0, requestID = 0
  async function refresh(minRevision = 0): Promise<void> {
    const owner = generation, request = ++requestID
    loading.value = true
    try {
      const result = await read()
      if (owner === generation && result.revision >= Math.max(revision.value, minRevision)) {
        name.value = result.name; revision.value = result.revision
      }
    } catch { /* Keep the last public profile during outages. */ }
    finally { if (owner === generation && request === requestID) loading.value = false }
  }
  function reset(): void { generation++; name.value = 'BOOHTACORD'; revision.value = 0; loading.value = false }
  return { name, revision, loading, refresh, reset }
}
export const guildProfile = createGuildProfileState()
