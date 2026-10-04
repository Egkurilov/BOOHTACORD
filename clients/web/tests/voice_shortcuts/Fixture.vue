<script setup lang="ts">
import { onBeforeUnmount, reactive, ref } from 'vue'
import ShortcutSettings from '../../src/voice/activation/ShortcutSettings.vue'
import Status from '../../src/voice/shortcuts/Status.vue'
import { createShortcutSettings } from '../../src/voice/shortcuts/state'
import { VoiceShortcuts } from '../../src/voice/shortcuts/runtime'
import { executeVoiceShortcut, type ShortcutVoice } from '../../src/voice/shortcuts/execute'
const error = ref<string|null>(null), settings = createShortcutSettings(error, ref(null))
const { microphoneShortcut, deafenShortcut, shortcutStatus } = settings
settings.bindAccount('fixture-a')
const voice = reactive<ShortcutVoice>({ active: { listenerOnly: false }, state: 'CONNECTED', deafenChanging: false, deafened: false, microphonePermissionDenied: false, microphoneMuted: true,
 toggleMicrophone: async (): Promise<void> => { voice.microphoneMuted = !voice.microphoneMuted }, toggleDeafen: async (): Promise<void> => { voice.deafened = !voice.deafened } })
const shortcuts = new VoiceShortcuts(window, () => ({ microphone: microphoneShortcut.value, deafen: deafenShortcut.value }), {
 microphone: () => executeVoiceShortcut('microphone', voice, 'VAD'), deafen: () => executeVoiceShortcut('deafen', voice, 'VAD'),
}, (action,result) => { shortcutStatus.value = result === 'blocked' ? 'Действие недоступно.' : action === 'microphone' ? voice.microphoneMuted ? 'Микрофон выключен.' : 'Микрофон включён.' : voice.deafened ? 'Звук выключен.' : 'Звук включён.' })
shortcuts.start(); onBeforeUnmount(() => shortcuts.stop())
const modal = ref<HTMLDialogElement|null>(null)
</script>
<template>
 <ShortcutSettings :microphone-shortcut="microphoneShortcut" :deafen-shortcut="deafenShortcut" @set-shortcut="settings.setShortcut" @reset-shortcuts="settings.resetShortcuts" />
 <p role="alert" v-if="error">{{ error }}</p><Status :message="shortcutStatus" />
 <input aria-label="Сообщение"><button @click="modal?.showModal()">Открыть диалог</button>
 <dialog ref="modal"><p>Диалог</p><button @click="modal?.close()">Закрыть</button></dialog>
 <div tabindex="0" aria-label="Рабочая область">Микрофон {{ voice.microphoneMuted ? 'off' : 'on' }}</div>
</template>
