import { clearDraftIfRevision, draftKey, draftRevision } from './draft_memory'
import { useComposerScope } from './composer_scope'

interface RetryMessage {
  clientMessageId: string
  body: string
  replyToId?: string
  attachments: { id: string }[]
  mentionUserIds: string[]
}

export function useScopedSend<Reply extends { id: string }, Attachment extends { id: string }, Message extends RetryMessage>(
  accountId: string,
  kind: 'CHANNEL' | 'DIRECT_MESSAGE',
  conversationId: () => string,
  composer: ReturnType<typeof useComposerScope<Reply, Attachment>>,
  canSend: () => boolean,
  submit: () => Promise<boolean>,
  retryRequest: (clientMessageId: string) => Promise<boolean>,
) {
  function capture(target: string) {
    const key = draftKey(accountId, kind, target)
    return { key, revision: draftRevision(key), snapshot: composer.snapshot(target) }
  }
  function clearSuccessful(target: string, saved: ReturnType<typeof capture>): void {
    clearDraftIfRevision(saved.key, saved.revision)
    if (conversationId() === target && composer.unchanged(saved.snapshot, target)) composer.clear()
  }
  async function send(): Promise<void> {
    if (!canSend()) return
    const target = conversationId()
    const saved = capture(target)
    if (await submit()) clearSuccessful(target, saved)
  }
  async function retry(message: Message): Promise<void> {
    const target = conversationId()
    const saved = capture(target)
    const matches = composer.matchesMessage(message)
    if (await retryRequest(message.clientMessageId) && matches) clearSuccessful(target, saved)
  }
  return { send, retry }
}
