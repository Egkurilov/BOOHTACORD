import { defineStore } from 'pinia'
import { ref } from 'vue'

export type SelectedSurface =
  | { kind: 'NONE' }
  | { kind: 'TEXT' | 'VOICE'; channelId: string }
  | { kind: 'DM'; directMessageId: string }

export const useVoiceNavigationStore = defineStore('voice-navigation', () => {
  const selectedSurface = ref<SelectedSurface>({ kind: 'NONE' })
  const activeVoiceChannelId = ref<string | null>(null)

  function selectText(channelId: string): void {
    selectedSurface.value = { kind: 'TEXT', channelId }
  }

  function selectVoice(channelId: string): void {
    selectedSurface.value = { kind: 'VOICE', channelId }
  }

  function selectDirectMessage(directMessageId: string): void {
    selectedSurface.value = { kind: 'DM', directMessageId }
  }

  function clearSelectedText(channelId: string): void {
    if (selectedSurface.value.kind === 'TEXT' && selectedSurface.value.channelId === channelId) selectedSurface.value = { kind: 'NONE' }
  }

  function clearSelectedVoice(channelId: string): void {
    if (selectedSurface.value.kind === 'VOICE' && selectedSurface.value.channelId === channelId) selectedSurface.value = { kind: 'NONE' }
  }

  function confirmVoiceConnected(channelId: string): void {
    activeVoiceChannelId.value = channelId
  }

  function clearActiveVoice(): void {
    activeVoiceChannelId.value = null
  }

  return {
    activeVoiceChannelId,
    clearActiveVoice,
    clearSelectedText,
    clearSelectedVoice,
    confirmVoiceConnected,
    selectedSurface,
    selectDirectMessage,
    selectText,
    selectVoice,
  }
})
