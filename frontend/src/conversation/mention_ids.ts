export function parseMentionIds(value: unknown): string[] {
  if (!Array.isArray(value) || value.length > 100 || value.some((id) => typeof id !== 'string' || !id)
    || new Set(value).size !== value.length) throw new Error('Сервер вернул некорректные упоминания.')
  return value as string[]
}

export function addMentionId(current: string[], candidateId: string, selfId?: string): string[] {
  if (!candidateId || candidateId === selfId || current.includes(candidateId) || current.length >= 100) return current
  return [...current, candidateId]
}
