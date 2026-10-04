import { createApp, h, reactive } from 'vue'
import VoiceDock from '../../../src/voice/VoiceDock.vue'
import WorkspaceUserFooter from '../../../src/workspace/WorkspaceUserFooter.vue'
import '../../../src/style.css'

const props = reactive({
  channel: { id: 'voice-1', name: 'Общий', kind: 'VOICE' }, activeSession: true,
  state: 'CONNECTED', error: null, activationMode: 'VAD', deafened: false,
  deafenChanging: false, microphoneMuted: false, microphonePermissionDenied: false,
  screenShareState: 'IDLE', connectionQuality: 'GOOD', pingMs: null, participantCount: 4,
})
const account = reactive({ role: 'MEMBER', displayName: 'Егор', accountID: 'egor-2', online: true })
const events = []
window.dockFixture = { props, account, events }
createApp({ render: () => h('aside', { class: 'sidebar is-open' }, [
  h(VoiceDock, { ...props, class: 'mobile-voice-dock',
    onToggleMicrophone: () => { events.push('microphone'); props.microphoneMuted = !props.microphoneMuted },
    onToggleDeafen: () => { events.push('deafen'); props.deafened = !props.deafened },
    onStartScreen: () => { events.push('startScreen'); props.screenShareState = 'SHARING' },
    onStopScreen: () => { events.push('stopScreen'); props.screenShareState = 'IDLE' },
    onLeave: () => { events.push('leave'); props.state = 'IDLE'; props.activeSession = false; props.channel = null },
  }),
  h(WorkspaceUserFooter, { ...account, onOpenSettings: () => events.push('settings'), onOpenProfile: () => events.push('profile') }),
]) }).mount('#fixture')
