import { onBeforeUnmount, ref } from 'vue'

export function useProtectedImagePreview(previewUrl: () => string, isOpen: () => boolean) {
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
      const response = await fetch(previewUrl(), {
        credentials: 'same-origin', cache: 'no-store', headers: { accept: 'image/png' },
      })
      if (!response.ok) {
        unavailable.value = response.status === 404 || response.status === 410
        throw new Error('preview unavailable')
      }
      const blob = await response.blob()
      if (revision !== requestRevision || !isOpen()) return
      revokePreview()
      objectUrl = URL.createObjectURL(blob)
      imageUrl.value = objectUrl
    } catch {
      if (revision === requestRevision) failed.value = true
    } finally {
      if (revision === requestRevision) loading.value = false
    }
  }

  function cancelPreview(): void {
    requestRevision++
    loading.value = false
    revokePreview()
  }

  onBeforeUnmount(cancelPreview)
  return { imageUrl, loading, unavailable, failed, loadPreview, cancelPreview }
}
