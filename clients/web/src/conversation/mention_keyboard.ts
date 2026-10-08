export interface MentionKeydownTarget {
  tagName?: string
  id?: string
}

export interface MentionKeydownEvent {
  isComposing?: boolean
  keyCode?: number
  target?: unknown
}

export function isMentionComposerTarget(target: unknown): boolean {
  const input = target as MentionKeydownTarget | null
  return input?.tagName === 'TEXTAREA' && ['message-body', 'direct-message-body'].includes(input.id ?? '')
}

export function canHandleMentionKeydown(event: MentionKeydownEvent, compositionActive: boolean): boolean {
  return !compositionActive && !event.isComposing && event.keyCode !== 229 && isMentionComposerTarget(event.target)
}
