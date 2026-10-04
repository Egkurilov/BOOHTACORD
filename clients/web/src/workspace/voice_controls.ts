import { computed, onBeforeUnmount, onMounted, watch } from 'vue'

import type { TopologyChannel } from '../channel/topology_client'
import { useTopologyStore } from '../channel/topology_store'
import { useAudioSettingsStore } from '../voice/audio_settings_store'
import type { AudioDeviceKind } from '../voice/audio_devices'
import { useVoiceActivationStore } from '../voice/activation_store'
import { useVoiceConnectionStore } from '../voice/connection_store'
import type { ScreenProfile, VoiceJoinMode } from '../voice/livekit_gateway'
import { useVoiceNavigationStore } from '../voice/navigation_store'
import { streamStartChime } from '../voice/stream_start_runtime'

export function useWorkspaceVoiceControls() {
  const topologyStore = useTopologyStore()
  const audioSettings = useAudioSettingsStore()
  const voiceActivation = useVoiceActivationStore()
  const voiceConnection = useVoiceConnectionStore()
  const voiceNavigation = useVoiceNavigationStore()
  watch(() => voiceConnection.inputSelection, (selection) => { if (selection) audioSettings.observeInput(selection) })
  const refreshDevices = () => { void loadAudioDevices() }
  onMounted(() => navigator.mediaDevices?.addEventListener?.('devicechange', refreshDevices))
  onBeforeUnmount(() => navigator.mediaDevices?.removeEventListener?.('devicechange', refreshDevices))

  async function loadAudioDevices(): Promise<void> {
    await audioSettings.loadInput(voiceConnection.setInputDevice)
    await audioSettings.load()
    await audioSettings.reconcileInput(voiceConnection.setInputDevice)
  }

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

  watch(() => topologyStore.topology, (topology) => {
    if (!topology) return
    const selected = voiceNavigation.selectedSurface
    if (selected.kind === 'DM') return
    const channels = topology.categories.flatMap(({ channels }) => channels)
    if (selected.kind === 'TEXT' || selected.kind === 'VOICE') {
      if (channels.some(({ id }) => id === selected.channelId)) return
      if (selected.kind === 'TEXT') voiceNavigation.clearSelectedText(selected.channelId)
      else voiceNavigation.clearSelectedVoice(selected.channelId)
    }
    const firstText = channels.find(({ kind }) => kind === 'TEXT')
    if (firstText) voiceNavigation.selectText(firstText.id)
  })

  function selectChannel(channel: TopologyChannel): void {
    if (channel.kind === 'TEXT') voiceNavigation.selectText(channel.id)
    else voiceNavigation.selectVoice(channel.id)
  }

  function selectDirectMessage(directMessageId: string): void {
    voiceNavigation.selectDirectMessage(directMessageId)
  }

  async function joinVoice(channelId: string, transfer = true, joinMode: VoiceJoinMode = 'with-microphone'): Promise<void> {
    const activeChannelId = voiceConnection.active?.channelId
    streamStartChime.activate()
    if (activeChannelId && activeChannelId !== channelId) await leaveVoice()
    await audioSettings.loadInput(voiceConnection.setInputDevice)
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
    if (kind === 'audioinput') await audioSettings.selectInput(deviceId, voiceConnection.setInputDevice)
    else await audioSettings.select(kind, deviceId, voiceConnection.switchAudioDevice)
  }

  return { activeVoiceChannel, audioSettings, loadAudioDevices, joinVoice, leaveVoice, selectAudioDevice, selectedChannel, selectedChannelId, selectChannel, selectDirectMessage, startScreen, topologyStore, voiceActivation, voiceConnection }
}
