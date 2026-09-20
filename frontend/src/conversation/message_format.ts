export type MessageSpan = { kind: 'TEXT' | 'BOLD' | 'ITALIC' | 'CODE' | 'LINK'; value: string; href?: string }
export type MessageBlock = { kind: 'PARAGRAPH'; spans: MessageSpan[] } | { kind: 'CODE_BLOCK'; value: string }

function append(spans: MessageSpan[], span: MessageSpan): void {
  const previous = spans.at(-1)
  if (span.kind === 'TEXT' && previous?.kind === 'TEXT') previous.value += span.value
  else spans.push(span)
}

function safeLink(value: string): string | null {
  try {
    const url = new URL(value)
    return url.protocol === 'https:' || url.protocol === 'http:' ? url.href : null
  } catch {
    return null
  }
}

function wrapped(source: string, position: number, marker: string, kind: MessageSpan['kind']): [MessageSpan, number] | null {
  const end = source.indexOf(marker, position + marker.length)
  if (end < position + marker.length) return null
  return [{ kind, value: source.slice(position + marker.length, end) }, end + marker.length]
}

export function formatInline(source: string): MessageSpan[] {
  const result: MessageSpan[] = []
  for (let position = 0; position < source.length;) {
    const marker = source.startsWith('**', position) ? wrapped(source, position, '**', 'BOLD')
      : source[position] === '*' ? wrapped(source, position, '*', 'ITALIC')
        : source[position] === '`' ? wrapped(source, position, '`', 'CODE') : null
    if (marker) {
      result.push(marker[0])
      position = marker[1]
      continue
    }
    if (source[position] === '[') {
      const labelEnd = source.indexOf('](', position + 1)
      const urlEnd = labelEnd < 0 ? -1 : source.indexOf(')', labelEnd + 2)
      const href = urlEnd < 0 ? null : safeLink(source.slice(labelEnd + 2, urlEnd))
      if (labelEnd > position + 1 && href) {
        result.push({ kind: 'LINK', value: source.slice(position + 1, labelEnd), href })
        position = urlEnd + 1
        continue
      }
    }
    append(result, { kind: 'TEXT', value: source[position] })
    position++
  }
  return result
}

export function formatMessage(source: string): MessageBlock[] {
  const segments = source.split('```')
  const result: MessageBlock[] = []
  segments.forEach((segment, index) => {
    if (index % 2 === 1) result.push({ kind: 'CODE_BLOCK', value: segment.replace(/^\n|\n$/g, '') })
    else segment.split(/\n{2,}/).filter(Boolean).forEach((paragraph) => result.push({ kind: 'PARAGRAPH', spans: formatInline(paragraph) }))
  })
  return result
}
