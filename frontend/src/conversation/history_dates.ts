export function chronologicalDatedMessages<T extends { createdAt: string }>(messages: readonly T[]) {
  let previousDay = ''
  return [...messages].reverse().map((message) => {
    const date = new Date(message.createdAt)
    const day = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
    const startsDay = day !== previousDay
    previousDay = day
    return {
      message,
      dateTime: startsDay ? day : undefined,
      dateLabel: startsDay ? `${date.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long' })} ${date.getFullYear()}` : undefined,
    }
  })
}
