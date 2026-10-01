<script setup lang="ts">
import { nextTick, onBeforeUnmount, ref } from 'vue'

const props = defineProps<{ name: string; previewUrl: string }>()

const dialog = ref<HTMLDialogElement | null>(null)
const closeButton = ref<HTMLButtonElement | null>(null)
const opener = ref<HTMLButtonElement | null>(null)
const imageUrl = ref<string | null>(null)
const loading = ref(false)
const unavailable = ref(false)
const failed = ref(false)
let requestRevision = 0
let objectUrl: string | null = null

function revokePreview(): void {
  if (objectUrl) URL.revokeObjectURL(objectUrl)
  objectUrl = null
  imageUrl.value = null
}

async function loadPreview(): Promise<void> {
  const revision = ++requestRevision
  loading.value = true
  unavailable.value = false
  failed.value = false
  try {
    const response = await fetch(props.previewUrl, {
      credentials: 'same-origin',
      cache: 'no-store',
      headers: { accept: 'image/png' },
    })
    if (!response.ok) {
      unavailable.value = response.status === 404 || response.status === 410
      throw new Error('preview unavailable')
    }
    const blob = await response.blob()
    if (revision !== requestRevision || !dialog.value?.open) return
    revokePreview()
    objectUrl = URL.createObjectURL(blob)
    imageUrl.value = objectUrl
  } catch {
    if (revision === requestRevision) failed.value = true
  } finally {
    if (revision === requestRevision) loading.value = false
  }
}

async function open(): Promise<void> {
  if (dialog.value?.open) return
  opener.value = document.activeElement instanceof HTMLButtonElement
    ? document.activeElement
    : null
  dialog.value?.showModal()
  await nextTick()
  closeButton.value?.focus()
  void loadPreview()
}

function restoreFocus(): void {
  requestRevision++
  loading.value = false
  revokePreview()
  if (opener.value?.isConnected) opener.value.focus()
  opener.value = null
}

function close(): void {
  if (dialog.value?.open) dialog.value.close()
  else restoreFocus()
}

function onCancel(event: Event): void {
  event.preventDefault()
  close()
}

function onDialogClick(event: MouseEvent): void {
  if (event.target !== dialog.value || !dialog.value) return
  const bounds = dialog.value.getBoundingClientRect()
  if (
    event.clientX < bounds.left || event.clientX > bounds.right ||
    event.clientY < bounds.top || event.clientY > bounds.bottom
  ) close()
}

onBeforeUnmount(() => {
  requestRevision++
  revokePreview()
})
</script>

<template>
  <button
    class="attachment-card__open"
    type="button"
    :aria-label="`Открыть изображение ${props.name}`"
    :title="`Открыть изображение ${props.name}`"
    @click="open"
  >
    <slot />
  </button>

  <dialog
    ref="dialog"
    class="attachment-image-dialog"
    :aria-label="`Просмотр изображения ${props.name}`"
    @cancel="onCancel"
    @click="onDialogClick"
    @close="restoreFocus"
  >
    <header class="attachment-image-dialog__header">
      <h2>{{ props.name }}</h2>
      <button
        ref="closeButton"
        type="button"
        class="attachment-image-dialog__close"
        aria-label="Закрыть просмотр изображения"
        @click="close"
      >
        <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18" /></svg>
      </button>
    </header>
    <div class="attachment-image-dialog__content" aria-live="polite" :aria-busy="loading">
      <p v-if="loading" class="attachment-image-dialog__status">Загружаем изображение…</p>
      <img
        v-else-if="imageUrl && !failed"
        :src="imageUrl"
        :alt="props.name"
        class="attachment-image-dialog__image"
        @error="failed = true"
      >
      <div v-else class="attachment-image-dialog__error" role="status">
        <span>{{ unavailable ? 'Вложение удалено или недоступно.' : 'Не удалось загрузить изображение.' }}</span>
        <button v-if="!unavailable" type="button" @click="loadPreview">Повторить</button>
      </div>
    </div>
  </dialog>
</template>
