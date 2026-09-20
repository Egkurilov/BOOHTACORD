import { defineStore } from 'pinia'
import { ref } from 'vue'

import { loadTopology, type ChannelTopology, type TopologyRequest } from './topology_client'

export const useTopologyStore = defineStore('channel-topology', () => {
  const topology = ref<ChannelTopology | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function refresh(request?: TopologyRequest): Promise<void> {
    loading.value = true
    error.value = null
    try {
      topology.value = await loadTopology(request)
    } catch (cause) {
      error.value = cause instanceof Error ? cause.message : 'Не удалось получить каналы.'
    } finally {
      loading.value = false
    }
  }

  return { topology, loading, error, refresh }
})
