import { createApp, defineComponent, h, onMounted, ref } from 'vue'
import '../../src/style.css'
import ScreenViewer from '../../src/voice/ScreenViewer.vue'
import ScreenShareSetupDialog from '../../src/voice/ScreenShareSetupDialog.vue'
import VoiceParticipantVolumes from '../../src/voice/VoiceParticipantVolumes.vue'
import PublishedAttachmentCard from '../../src/conversation/attachment_card/PublishedAttachmentCard.vue'
import type { ScreenViewerCard } from '../../src/voice/screen_viewer_controller'
import type { ScreenProfile } from '../../src/voice/livekit_gateway'

const state = new URLSearchParams(location.search).get('state') ?? 'stream'
const streams: ScreenViewerCard[] = [{ id: 'qa-stream', accountId: 'qa-alex', participantId: 'qa-alex', participantName: 'Alex', hasAudio: true, isLocal: false, targetProfile: 'P1440_60' }]
const App = defineComponent({ setup: () => {
  const opened = ref(false)
  onMounted(() => {
    if (state === 'quality') setTimeout(() => { document.querySelector<HTMLDialogElement>('dialog')?.showModal() }, 0)
    if (state === 'statistics') setTimeout(() => { const details = document.querySelector<HTMLDetailsElement>('.stream-diagnostics'); if (details) details.open = true }, 100)
  })
  const viewer = () => h('main', { class: 'media-main' }, [h(ScreenViewer, { audioMuted: false, cards: streams, deafened: false, ended: false, error: null, expanded: false, selectedAudioVolume: 100, selectedId: 'qa-stream', onClear: () => undefined, onPin: () => undefined, onReturnVoice: () => undefined, onSelect: () => undefined, onSetAudioVolume: () => undefined, onToggleAudio: () => undefined, 'onUpdate:expanded': () => undefined })])
  const quality = () => h(ScreenShareSetupDialog, { initialProfile: 'P1440_60' as ScreenProfile, onCancel: () => { opened.value = false }, onStart: () => undefined })
  const participants = () => h('main', { class: 'media-main' }, [h(VoiceParticipantVolumes, { error: null, participants: ['Alex', 'Daria', 'Max'].map((name, index) => ({ id: `qa-${name.toLowerCase()}`, accountId: `qa-${name.toLowerCase()}`, name, volume: 100, speaking: name === 'Alex', microphoneMuted: false })), screenStreams: streams, selectedScreenStreamId: 'qa-stream', selfName: 'Егор', selfDeafened: false, selfMicrophoneMuted: false, selfMicrophoneUnavailable: false, selfSpeaking: false, onSetVolume: () => undefined, onWatchScreen: () => undefined })])
  const attachment = () => h('main', { class: 'media-main' }, [h('ul', { class: 'message-attachments' }, [h(PublishedAttachmentCard, { attachment: { id: 'qa-attachment', originalName: 'review.png', sizeBytes: 2400000 }, downloadUrl: '/api/v1/media/qa/download', previewUrl: '/api/v1/media/qa/preview' })])])
  if (state === 'quality') return () => h('main', { class: 'media-main' }, [quality()])
  if (state === 'statistics') return viewer
  if (state === 'voice') return () => h('main', { class: 'media-main' }, [participants()])
  if (state === 'image') return attachment
  return () => viewer()
} })

createApp(App).mount('#app')
