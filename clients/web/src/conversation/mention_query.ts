export interface MentionQuery { start: number; query: string }

export function activeMentionQuery(text: string): MentionQuery | null {
  const match = /(?:^|\s)@([^\s@]*)$/.exec(text)
  if (!match) return null
  return { start: match.index + match[0].length - match[1].length - 1, query: match[1] }
}

export function replaceMentionQuery(text: string, displayName: string): string {
  const active = activeMentionQuery(text)
  if (!active) return text
  const at = active.start
  const end = at + active.query.length + 1
  return `${text.slice(0, at)}@${displayName} ${text.slice(end)}`
}
