import { onBeforeUnmount, watch } from 'vue'

import { draftKey, draftMemoryEpoch, loadDraft, saveDraft } from './draft_memory'
import { useComposerScope } from './composer_scope'

export function useSavedComposer<Reply extends { id: string }, Attachment extends { id: string }>(
  accountId: string, kind: 'CHANNEL' | 'DIRECT_MESSAGE', conversationId: () => string,
) {
  const composer = useComposerScope<Reply, Attachment>()
  const { draft, replyTarget, attachments, mentionUserIds } = composer
  let key = ''
  let restoring = false
  const epoch = draftMemoryEpoch()

  function remember(): void {
    if (!key || restoring || epoch !== draftMemoryEpoch()) return
    saveDraft(key, { body: draft.value, replyTarget: replyTarget.value,
      attachments: attachments.value, mentionUserIds: mentionUserIds.value })
  }

  watch(conversationId, (id) => {
    remember()
    key = draftKey(accountId, kind, id)
    restoring = true
    composer.reset()
    const saved = loadDraft<Reply, Attachment>(key)
    if (saved) {
      draft.value = saved.body
      replyTarget.value = saved.replyTarget
      attachments.value = saved.attachments
      mentionUserIds.value = saved.mentionUserIds
    }
    restoring = false
  }, { immediate: true, flush: 'sync' })
  watch([draft, replyTarget, attachments, mentionUserIds], remember, { flush: 'sync' })
  onBeforeUnmount(remember)
  return composer
}
