<script setup lang="ts">
import { ref } from 'vue'
import { captureVoiceShortcutAssignment, formatVoiceShortcut, type VoiceShortcutAction, type VoiceShortcutBinding } from '../voice_shortcut'
const props = defineProps<{ microphoneShortcut?: VoiceShortcutBinding | null; deafenShortcut?: VoiceShortcutBinding | null }>()
const emit = defineEmits<{ setShortcut: [action: VoiceShortcutAction, binding: VoiceShortcutBinding | null] }>()
const recordingShortcut = ref<VoiceShortcutAction | null>(null)
const shortcutActions: VoiceShortcutAction[] = ['microphone', 'deafen']
function captureShortcut(event: KeyboardEvent): void {
  const action = recordingShortcut.value
  if (!action) return
  captureVoiceShortcutAssignment(event, () => { recordingShortcut.value = null }, (binding) => emit('setShortcut', action, binding), () => emit('setShortcut', action, null))
}

function shortcutValue(action: VoiceShortcutAction): VoiceShortcutBinding | null {
  return action === 'microphone' ? props.microphoneShortcut ?? null : props.deafenShortcut ?? null
}

</script>
<template>
      <section class="audio-shortcuts-section" aria-labelledby="audio-shortcuts-title"><header><h2 id="audio-shortcuts-title">Сочетания клавиш</h2><p>Работают в активной вкладке, кроме полей ввода и диалогов.</p></header>
        <div v-for="shortcut in shortcutActions" :key="shortcut" class="audio-shortcut-row">
          <span>{{ shortcut === 'microphone' ? 'Микрофон' : 'Выключить звук' }}<small>{{ formatVoiceShortcut(shortcutValue(shortcut)) }}</small></span>
          <span class="audio-shortcut-actions"><button type="button" :aria-label="`Назначить сочетание: ${shortcut === 'microphone' ? 'микрофон' : 'выключить звук'}`" :aria-keyshortcuts="formatVoiceShortcut(shortcutValue(shortcut))" @click="recordingShortcut = shortcut" @keydown="captureShortcut">{{ recordingShortcut === shortcut ? 'Нажмите сочетание…' : 'Назначить' }}</button><button v-if="shortcutValue(shortcut)" type="button" @click="emit('setShortcut', shortcut, null)">Очистить</button></span>
        </div>
      </section>
</template>
