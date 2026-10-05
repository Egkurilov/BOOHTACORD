import { createApp, h } from 'vue'
import { createPinia } from 'pinia'
import VoicePrejoin from '../../src/voice/VoicePrejoin.vue'
import { disconnectNotice, type VoiceDisconnectNotice } from '../../src/voice/disconnect_notice/model'
import '../../src/style.css'
const reason = (new URLSearchParams(location.search).get('reason') ?? 'KICK') as VoiceDisconnectNotice['reason']
createApp({ render: () => h(VoicePrejoin, {
  channelId: 'synthetic-channel', voiceState: 'ERROR', voiceError: 'technical error', voiceTransferRequired: false,
  roster: { channelId: 'synthetic-channel', participants: [], revision: 1 },
  notice: disconnectNotice(reason, reason === 'TRANSPORT' ? 'transport' : 'server'),
  onJoin: (...args: unknown[]) => { document.body.dataset.join = JSON.stringify(args) },
}) }).use(createPinia()).mount('#app')
