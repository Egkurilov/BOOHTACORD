import { computed, ref, watch } from 'vue'
import type { TopologyChannel } from '../channel/topology_client'
import { miniPlayerVisible, screenViewerMounted } from './mini_player_policy'
import { screenCaptureSupported, screenCaptureUnavailableMessage } from './screen_capture_support'
import type { ScreenViewerCard } from './screen_viewer_controller'

interface ConversationScreenProps {
  visible: boolean
  channel: TopologyChannel | null
  activeVoiceChannel: TopologyChannel | null
  directMessage: unknown
  selectedScreenStreamId: string | null
  screenViewerCards: ScreenViewerCard[]
}

export function useConversationScreenState(props: ConversationScreenProps) {
  const screenCaptureAvailable = screenCaptureSupported()
  const captureUnavailableMessage = screenCaptureUnavailableMessage()
  const screenExpanded = ref(false)
  const screenPinned = ref(false)
  const voiceVisible = computed(() => props.visible && !props.directMessage && props.channel?.kind === 'VOICE')
  const voiceChannel = computed(() => props.channel?.kind === 'VOICE' ? props.channel : props.activeVoiceChannel)
  const miniVisible = computed(() => miniPlayerVisible(screenPinned.value, voiceVisible.value, props.selectedScreenStreamId, props.activeVoiceChannel?.id ?? null))
  const keepVoiceRoom = computed(() => screenViewerMounted(screenPinned.value, voiceVisible.value, props.selectedScreenStreamId, props.activeVoiceChannel?.id ?? null))
  const selectedScreenName = computed(() => props.screenViewerCards.find((screen) => screen.id === props.selectedScreenStreamId)?.participantName ?? null)
  const screenViewerRef = ref<{ selectStream: (id: string) => void } | null>(null)
  watch(() => props.selectedScreenStreamId, (id) => { if (!id) screenPinned.value = false })
  watch(miniVisible, (visible) => { if (visible) screenExpanded.value = false })
  function watchScreen(id: string): void { screenViewerRef.value?.selectStream(id) }
  return { screenCaptureAvailable, captureUnavailableMessage, screenExpanded, screenPinned,
    voiceChannel, miniVisible, keepVoiceRoom, selectedScreenName, screenViewerRef, watchScreen }
}
