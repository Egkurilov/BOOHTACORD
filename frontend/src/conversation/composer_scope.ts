import { ref, shallowRef } from 'vue'

interface ScopedMessage { body: string; replyToId?: string; attachments: { id: string }[]; mentionUserIds: string[] }
interface ComposerSnapshot { generation: number; key: string }

export function useComposerScope<Reply extends { id: string }, Attachment extends { id: string }>() {
  const draft = ref('')
  const replyTarget = shallowRef<Reply | null>(null)
  const attachments = shallowRef<Attachment[]>([])
  const mentionUserIds = ref<string[]>([])
  const attachmentPending = ref(false)
  const attachmentClearToken = ref(0)
  let generation = 0

  function key(target: string): string {
    return JSON.stringify([target, draft.value, replyTarget.value?.id, attachments.value.map(({ id }) => id), mentionUserIds.value])
  }

  function snapshot(target: string): ComposerSnapshot { return { generation, key: key(target) } }
  function unchanged(saved: ComposerSnapshot, target: string): boolean { return saved.generation === generation && saved.key === key(target) }

  function matchesMessage(message: ScopedMessage): boolean {
    return draft.value === message.body && replyTarget.value?.id === message.replyToId
      && JSON.stringify(attachments.value.map(({ id }) => id)) === JSON.stringify(message.attachments.map(({ id }) => id))
      && JSON.stringify(mentionUserIds.value) === JSON.stringify(message.mentionUserIds)
  }

  function clear(): void {
    generation++
    draft.value = ''
    replyTarget.value = null
    attachments.value = []
    mentionUserIds.value = []
    attachmentPending.value = false
    attachmentClearToken.value++
  }

  return { draft, replyTarget, attachments, mentionUserIds, attachmentPending, attachmentClearToken, snapshot, unchanged, matchesMessage, clear, reset: clear }
}
