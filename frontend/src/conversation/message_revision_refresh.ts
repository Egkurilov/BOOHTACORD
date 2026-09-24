interface Page<Item> { messages: Item[]; nextCursor?: string }

/** Revisit only the portion of history already loaded by the user, plus two pages for recent arrivals. */
export async function findLoadedMessage<Item extends { id: string }>(
  messageId: string,
  loadedCount: number,
  load: (before?: string) => Promise<Page<Item>>,
  stillCurrent: () => boolean,
): Promise<Item | null> {
  const seenCursors = new Set<string>()
  const maxPages = Math.max(1, Math.ceil(loadedCount / 50) + 2)
  let before: string | undefined
  for (let page = 0; page < maxPages && stillCurrent(); page++) {
    const result = await load(before)
    if (!stillCurrent()) return null
    const found = result.messages.find(({ id }) => id === messageId)
    if (found) return found
    if (!result.nextCursor || seenCursors.has(result.nextCursor)) return null
    before = result.nextCursor
    seenCursors.add(before)
  }
  return null
}
