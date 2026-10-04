export function insertEmojiAtRange(text: string, start: number, end: number, emoji: string): { text: string; caret: number } {
  const from = Math.max(0, Math.min(text.length, Math.min(start, end)))
  const to = Math.max(from, Math.min(text.length, Math.max(start, end)))
  return { text: `${text.slice(0, from)}${emoji}${text.slice(to)}`, caret: from + emoji.length }
}
