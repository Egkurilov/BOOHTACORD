<script setup lang="ts">
import { nextTick, onBeforeUnmount, ref } from 'vue'

const props = defineProps<{ id: string; title: string; confirmLabel: string }>()
const dialog = ref<HTMLDialogElement | null>(null)
const message = ref('')
let answer: ((confirmed: boolean) => void) | null = null
let opener: HTMLElement | null = null

async function ask(text: string): Promise<boolean> {
  if (answer) return false
  opener = document.activeElement as HTMLElement | null
  message.value = text
  await nextTick()
  return new Promise<boolean>((resolve) => {
    answer = resolve
    try { dialog.value?.showModal() } catch { settle(false) }
    if (!dialog.value) settle(false)
  })
}

function settle(confirmed: boolean): void {
  if (!answer) return
  const resolve = answer
  answer = null
  if (dialog.value?.open) dialog.value.close()
  resolve(confirmed)
  if (!confirmed) void nextTick(() => { if (opener?.isConnected) opener.focus() })
}

onBeforeUnmount(() => settle(false))
defineExpose({ ask })
</script>

<template>
  <dialog ref="dialog" class="admin-confirm-dialog" aria-modal="true" :aria-labelledby="`${props.id}-title`" :aria-describedby="`${props.id}-message`" @cancel.prevent="settle(false)" @close="settle(false)">
    <h3 :id="`${props.id}-title`">{{ title }}</h3>
    <p :id="`${props.id}-message`">{{ message }}</p>
    <div class="admin-confirm-actions">
      <button type="button" autofocus @click="settle(false)">Отмена</button>
      <button type="button" @click="settle(true)">{{ confirmLabel }}</button>
    </div>
  </dialog>
</template>
