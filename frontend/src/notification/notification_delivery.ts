export interface NotificationRuntime {
  permission(): NotificationPermission | 'unavailable'
  requestPermission(): Promise<NotificationPermission>
  show(title: string, options: NotificationOptions): void
  storage: Pick<Storage, 'getItem' | 'setItem'> | null
  lock: (<T>(key: string, action: () => Promise<T>) => Promise<T>) | null
}

export function browserNotificationRuntime(): NotificationRuntime {
  let storage: Storage | null = null
  try { if (typeof window !== 'undefined') storage = window.localStorage } catch { /* Private browsing can deny storage. */ }
  const api = typeof Notification === 'undefined' ? null : Notification
  const locks = typeof navigator === 'undefined' ? null : navigator.locks
  return {
    permission: () => api?.permission ?? 'unavailable',
    requestPermission: () => api?.requestPermission() ?? Promise.resolve('denied'),
    show: (title, options) => { if (api) new api(title, options) },
    storage,
    lock: locks ? async <T>(key: string, action: () => Promise<T>): Promise<T> => await locks.request<Promise<T>>(key, action) : null,
  }
}

function readSeen(storage: Pick<Storage, 'getItem'>, key: string): string[] {
  try {
    const parsed: unknown = JSON.parse(storage.getItem(key) ?? '[]')
    return Array.isArray(parsed) ? parsed.filter((id): id is string => typeof id === 'string').slice(-511) : []
  } catch { return [] }
}

export function createNotificationDelivery(accountID: string, runtime: NotificationRuntime = browserNotificationRuntime()) {
  const prefix = `boohtacord:notification:${accountID}`
  const preferenceKey = `${prefix}:enabled`
  const seenKey = `${prefix}:seen`
  const available = () => runtime.permission() !== 'unavailable' && runtime.storage !== null && runtime.lock !== null
  const enabled = () => available() && runtime.storage?.getItem(preferenceKey) === '1'

  return {
    available,
    enabled,
    permission: runtime.permission,
    async enable(): Promise<boolean> {
      if (!available()) return false
      const permission = runtime.permission() === 'granted' ? 'granted' : await runtime.requestPermission()
      runtime.storage!.setItem(preferenceKey, permission === 'granted' ? '1' : '0')
      return permission === 'granted'
    },
    disable(): void { runtime.storage?.setItem(preferenceKey, '0') },
    async deliver(eventID: string, body: string): Promise<void> {
      if (!enabled() || runtime.permission() !== 'granted') return
      await runtime.lock!(prefix, async () => {
        if (!enabled() || runtime.permission() !== 'granted') return
        const seen = readSeen(runtime.storage!, seenKey)
        if (seen.includes(eventID)) return
        runtime.storage!.setItem(seenKey, JSON.stringify([...seen, eventID]))
        runtime.show('Voice Platform', { body, tag: eventID })
      })
    },
  }
}
