import { createApp, defineComponent, h, ref } from 'vue'
import { createPinia } from 'pinia'
import WorkspaceMembersPanel from '../../src/workspace/WorkspaceMembersPanel.vue'
import type { TopologyChannel } from '../../src/channel/topology_client'
import type { VoiceVolumeParticipant } from '../../src/voice/voice_volume_controls'
import '../../src/style.css'

const channel: TopologyChannel = { id: 'qa-voice', name: 'Канал №1', kind: 'VOICE', position: 0, admissionClosed: false }
const modal = window.innerWidth < 1024
createApp(defineComponent({
  setup() {
    const participants = ref<VoiceVolumeParticipant[]>(['owner', 'member'].map((name) => ({
      id: `qa-session-${name}`, accountId: `qa-${name}`, name,
      microphoneMuted: false, speaking: name === 'owner', volume: 100,
    })))
    const stopPointer = (event: PointerEvent) => event.stopPropagation()
    return () => h('div', { class: 'app-frame' }, h('div', { class: 'gc-shell' }, [
      h('aside', { class: 'sidebar' }, h('div', { class: 'nav-drawer' }, [
        h('button', { 'data-testid': 'sidebar-control', onPointerdown: stopPointer }, 'Каналы'),
      ])),
      h('main', { class: 'main', onPointerdown: stopPointer }, [
        h('header', { class: 'main-header' }, [
          h('span', {}, 'Канал №1'),
          h('button', { 'data-testid': 'header-control' }, 'Настройки канала'),
        ]),
        h('div', { 'data-testid': 'voice-stage', style: 'flex:1;min-height:300px;' }, 'Голосовой канал'),
      ]),
      h(WorkspaceMembersPanel, {
        activeVoiceChannel: channel, selectedVoiceChannel: channel, participants: participants.value,
        presenceResolver: (_id, fallback) => fallback, role: 'ADMINISTRATOR', accountID: 'qa-self',
        selfMicrophoneMuted: false, selfMicrophoneUnavailable: false, selfName: 'Вы', open: true, modal,
        onSetVolume: (id: string, volume: number) => {
          const participant = participants.value.find((candidate) => candidate.id === id)
          if (participant) participant.volume = volume
        },
      }),
    ]))
  },
})).use(createPinia()).mount('#app')
