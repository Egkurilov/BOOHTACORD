import { defineStore } from 'pinia'
import { ref, watch, type WatchStopHandle } from 'vue'

import { useTopologyStore } from '../channel/topology_store'
import { useDirectMessageStore } from '../direct_message/direct_message_store'
import type { RealtimeEvent } from '../realtime/realtime_client'
import { createNotificationDelivery, type NotificationRuntime } from './notification_delivery'
import { addressedUnread, notificationCandidate, notificationTitle, unreadTotal } from './notification_policy'

export const useNotificationStore = defineStore('notifications', () => {
  const topology = useTopologyStore()
  const directMessages = useDirectMessageStore()
  const available = ref(false)
  const enabled = ref(false)
  const permission = ref<NotificationPermission | 'unavailable'>('unavailable')
  const error = ref<string | null>(null)
  let delivery: ReturnType<typeof createNotificationDelivery> | null = null
  let stopTitleWatch: WatchStopHandle | null = null
  let originalTitle = ''

  function refreshStatus(): void {
    try {
      available.value = delivery?.available() ?? false
      enabled.value = delivery?.enabled() ?? false
      permission.value = delivery?.permission() ?? 'unavailable'
    } catch {
      available.value = false
      enabled.value = false
      permission.value = 'unavailable'
    }
  }

  function start(accountID: string, runtime?: NotificationRuntime): void {
    stop()
    delivery = createNotificationDelivery(accountID, runtime)
    refreshStatus()
    if (typeof document === 'undefined') return
    originalTitle = document.title
    stopTitleWatch = watch(
      () => unreadTotal(topology.topology, directMessages.directMessages),
      (count) => { document.title = notificationTitle(originalTitle, count) },
      { immediate: true },
    )
  }

  function stop(): void {
    if (stopTitleWatch) { stopTitleWatch(); stopTitleWatch = null; document.title = originalTitle }
    delivery?.cancel()
    delivery = null
    refreshStatus()
  }

  async function enable(): Promise<void> {
    if (!delivery) return
    error.value = null
    try { await delivery.enable() }
    catch { error.value = 'Не удалось включить уведомления. Проверьте настройки браузера.' }
    refreshStatus()
  }

  function disable(): void {
    error.value = null
    try { delivery?.disable() }
    catch { error.value = 'Не удалось отключить уведомления. Проверьте настройки браузера.' }
    refreshStatus()
  }

  function capture(event: RealtimeEvent): number | null {
    const previous = addressedUnread(event, topology.topology, directMessages.directMessages)
    return previous ?? (event.kind === 'direct_message.message_created' ? 0 : null)
  }

  async function deliver(event: RealtimeEvent, previousUnread: number | null): Promise<void> {
    if (!delivery || previousUnread === null || typeof document === 'undefined' || document.visibilityState !== 'hidden') return
    const body = notificationCandidate(event, topology.topology, directMessages.directMessages, previousUnread)
    if (!body) return
    try { await delivery.deliver(event.eventId, body) } catch { /* Notification delivery must not break realtime recovery. */ }
    refreshStatus()
  }

  return { available, enabled, permission, error, start, stop, enable, disable, refreshStatus, capture, deliver }
})
