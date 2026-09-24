import { computed } from 'vue'

import type { TopologyChannel } from '../channel/topology_client'
import { useTopologyStore } from '../channel/topology_store'
import { useAudioSettingsStore } from '../voice/audio_settings_store'
import type { AudioDeviceKind } from '../voice/audio_devices'
import { useVoiceActivationStore } from '../voice/activation_store'
import { useVoiceConnectionStore } from '../voice/connection_store'
import type { ScreenProfile, VoiceJoinMode } from '../voice/livekit_gateway'
import { useVoiceNavigationStore } from '../voice/navigation_store'

export function useWorkspaceVoiceControls() {
  const topologyStore = useTopologyStore()
  const audioSettings = useAudioSettingsStore()
  const voiceActivation = useVoiceActivationStore()
  const voiceConnection = useVoiceConnectionStore()
  const voiceNavigation = useVoiceNavigationStore()

  function findChannel(channelId: string | undefined): TopologyChannel | null {
    if (!channelId || !topologyStore.topology) return null
    return topologyStore.topology.categories.flatMap((category) => category.channels).find((channel) => channel.id === channelId) ?? null
  }

  const selectedChannelId = computed(() => {
    const surface = voiceNavigation.selectedSurface
    return surface.kind === 'TEXT' || surface.kind === 'VOICE' ? surface.channelId : null
  })
  const selectedChannel = computed(() => findChannel(selectedChannelId.value ?? undefined))
  const activeVoiceChannel = computed(() => findChannel(voiceConnection.active?.channelId))

  function selectChannel(channel: TopologyChannel): void {
    if (channel.kind === 'TEXT') voiceNavigation.selectText(channel.id)
    else voiceNavigation.selectVoice(channel.id)
  }

  function selectDirectMessage(directMessageId: string): void {
    voiceNavigation.selectDirectMessage(directMessageId)
  }

  async function joinVoice(channelId: string, transfer = false, joinMode: VoiceJoinMode = 'with-microphone'): Promise<void> {
    const activeChannelId = voiceConnection.active?.channelId
    if (activeChannelId && activeChannelId !== channelId && !window.confirm('Выйти из текущего голосового канала и перейти в другой?')) return
    if (activeChannelId && activeChannelId !== channelId) await leaveVoice()
    await audioSettings.loadProcessing(voiceConnection.setAudioProcessing)
    await voiceConnection.join(channelId, transfer, joinMode)
    if (voiceConnection.active) voiceNavigation.confirmVoiceConnected(voiceConnection.active.channelId)
  }

  async function leaveVoice(): Promise<void> {
    await voiceActivation.stop(false)
    await voiceConnection.leave()
    if (!voiceConnection.active) voiceNavigation.clearActiveVoice()
  }

  async function startScreen(profile: ScreenProfile): Promise<void> {
    await voiceConnection.startScreen(profile)
  }

  async function selectAudioDevice(kind: AudioDeviceKind, deviceId: string): Promise<void> {
    await audioSettings.select(kind, deviceId, voiceConnection.switchAudioDevice)
  }

  return { activeVoiceChannel, audioSettings, joinVoice, leaveVoice, selectAudioDevice, selectedChannel, selectedChannelId, selectChannel, selectDirectMessage, startScreen, topologyStore, voiceActivation, voiceConnection }
}
