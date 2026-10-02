export function navigateToReplyTarget(
  root: HTMLElement | null,
  messageId: string,
  openMissingContext: () => void,
): void {
  const target = [...(root?.querySelectorAll<HTMLElement>('[data-message-id]') ?? [])]
    .find((item) => item.dataset.messageId === messageId)
  if (target) {
    target.scrollIntoView({ behavior: 'smooth', block: 'center' })
    return
  }
  openMissingContext()
}
