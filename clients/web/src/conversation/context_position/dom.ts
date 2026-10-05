export interface Position { id: string; offset: number }
export function capture(viewport: HTMLElement | null): Position | null {
  if (!viewport || viewport.clientHeight <= 0) return null
  const top = viewport.getBoundingClientRect().top
  const row = [...viewport.querySelectorAll<HTMLElement>('[data-message-id]')].find(item => item.getBoundingClientRect().bottom > top)
  return row?.dataset.messageId ? { id: row.dataset.messageId, offset: row.getBoundingClientRect().top - top } : null
}
export function restore(viewport: HTMLElement | null, position: Position): boolean {
  const row = [...(viewport?.querySelectorAll<HTMLElement>('[data-message-id]') ?? [])].find(item => item.dataset.messageId === position.id)
  if (!viewport || !row) return false
  viewport.scrollTop += row.getBoundingClientRect().top - viewport.getBoundingClientRect().top - position.offset
  return true
}
