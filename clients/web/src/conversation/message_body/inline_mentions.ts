import { formatMessage, type MessageSpan } from './message_format'

export interface MentionRecipient { id: string; name: string }
export type DecoratedSpan = MessageSpan | { kind: 'MENTION'; value: string; id: string }
export type DecoratedBlock = { kind: 'PARAGRAPH'; spans: DecoratedSpan[] } | { kind: 'CODE_BLOCK'; value: string }

function wordCharacter(value: string | undefined): boolean {
  return Boolean(value && /[\p{L}\p{N}_]/u.test(value))
}

function eligibleRecipients(recipients: readonly MentionRecipient[]): MentionRecipient[] {
  const counts = new Map<string, number>()
  for (const { name } of recipients) counts.set(name, (counts.get(name) ?? 0) + 1)
  return recipients.filter(({ name }) => name.trim() && counts.get(name) === 1)
}

function splitText(source: string, recipients: readonly MentionRecipient[], seen: Set<string>): DecoratedSpan[] {
  const result: DecoratedSpan[] = []
  let position = 0
  while (position < source.length) {
    let best: { index: number; recipient: MentionRecipient } | null = null
    for (const recipient of recipients) {
      const token = `@${recipient.name}`
      let index = source.indexOf(token, position)
      while (index >= 0 && (wordCharacter(source[index - 1]) || wordCharacter(source[index + token.length]))) {
        index = source.indexOf(token, index + 1)
      }
      if (index >= 0 && (!best || index < best.index || (index === best.index && token.length > best.recipient.name.length + 1))) {
        best = { index, recipient }
      }
    }
    if (!best) break
    if (best.index > position) result.push({ kind: 'TEXT', value: source.slice(position, best.index) })
    result.push({ kind: 'MENTION', value: `@${best.recipient.name}`, id: best.recipient.id })
    seen.add(best.recipient.id)
    position = best.index + best.recipient.name.length + 1
  }
  if (position < source.length) result.push({ kind: 'TEXT', value: source.slice(position) })
  return result
}

export function decorateMessageMentions(body: string, recipients: readonly MentionRecipient[]): { blocks: DecoratedBlock[]; unmatchedIds: string[] } {
  const seen = new Set<string>()
  const eligible = eligibleRecipients(recipients)
  const blocks: DecoratedBlock[] = formatMessage(body).map((block) => block.kind === 'CODE_BLOCK' ? block : {
    kind: 'PARAGRAPH', spans: block.spans.flatMap((span) => span.kind === 'TEXT' ? splitText(span.value, eligible, seen) : [span]),
  })
  return { blocks, unmatchedIds: recipients.filter(({ id }) => !seen.has(id)).map(({ id }) => id) }
}
