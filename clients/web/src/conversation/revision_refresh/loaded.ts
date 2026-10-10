import type { Ref } from 'vue'
import { requestFailureMessage } from '../../request_feedback'
interface Item { id: string; sendStatus?: string }
interface Page<T> { messages: T[]; nextCursor?: string }
interface Options<T extends Item, Request> {
  messages: Ref<T[]>; resourceId: Ref<string | null>; version: () => number;
  load: (id: string, before?: string, request?: Request) => Promise<Page<T>>;
  merge: (items: T[]) => void; error: Ref<string | null>; fallback: string;
}
export function createLoadedRevisionRefresh<T extends Item, Request>(options: Options<T, Request>) {
  async function refreshMessages(ids: string[], request?: Request): Promise<T[]> {
    const target = options.resourceId.value, version = options.version()
    const loaded = options.messages.value.filter(item => !item.sendStatus)
    const wanted = new Set(ids.filter(id => loaded.some(item => item.id === id)))
    if (!target || !wanted.size) return []
    const current = () => options.resourceId.value === target && options.version() === version
    const found: T[] = [], cursors = new Set<string>()
    let before: string | undefined
    try {
      for (let page = 0; page < Math.max(1, Math.ceil(loaded.length/50)+2) && current(); page++) {
        const result = await options.load(target, before, request)
        if (!current()) return []
        for (const item of result.messages) if (wanted.delete(item.id)) found.push(item)
        if (!wanted.size || !result.nextCursor || cursors.has(result.nextCursor)) break
        before = result.nextCursor; cursors.add(before)
      }
      if (current() && found.length) options.merge(found)
      return found
    } catch (cause) {
      if (current()) options.error.value = requestFailureMessage(cause, options.fallback)
      return []
    }
  }
  return { refreshMessages, async refreshMessage(id: string, request?: Request): Promise<T | null> {
    const found = await refreshMessages([id], request)
    return found.length ? options.messages.value.find(item => item.id === id) ?? null : null
  } }
}
