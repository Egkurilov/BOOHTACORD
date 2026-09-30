import { defineStore } from 'pinia'
import { ref } from 'vue'
import { loadCurrentSession } from '../identity/current_session'
import { parseRealtimeEvent, realtimeTraceURL, realtimeURL, type RealtimeEvent } from './realtime_client'
import { createRealtimeDelivery, type EventHandler } from './realtime_event_delivery'
import { reconnectDelay } from './reconnect_policy'
import type { RealtimeConnectOptions, RealtimeSocket, RealtimeSocketFactory } from './realtime_connection_types'
import { startTracedCompletion } from '../telemetry/client_tracing'

export type { RealtimeConnectOptions, RealtimeSocket, RealtimeSocketFactory } from './realtime_connection_types'
export type RealtimeState = 'IDLE' | 'CONNECTING' | 'CONNECTED' | 'DISCONNECTED' | 'ERROR'
export const useRealtimeStore = defineStore('realtime', () => {
  const state = ref<RealtimeState>('IDLE')
  const error = ref<string | null>(null)
  let socket: RealtimeSocket | null = null
  let timer: ReturnType<typeof setTimeout> | null = null
  let active = false
  let generation = 0
  let attempt = 0
  let delivery: ReturnType<typeof createRealtimeDelivery> | null = null
  let pendingConnection: (() => void) | null = null
  function connect(onEvent: EventHandler, factory: RealtimeSocketFactory = (url) => new WebSocket(url), url?: string, options: RealtimeConnectOptions = {}): void {
    if (active) return
    active = true
    const ownGeneration = ++generation
    attempt = 0
    state.value = 'CONNECTING'
    error.value = null
    delivery = createRealtimeDelivery(onEvent, options.onRecovery, (cause) => {
      if (ownGeneration !== generation) return
      error.value = cause instanceof Error ? cause.message : 'Не удалось обновить данные после восстановления связи.'
      state.value = 'ERROR'
      if (socket) fail(socket)
    })

    function schedule(): void {
      if (!active || ownGeneration !== generation || timer) return
      const delay = reconnectDelay(attempt++, options.random)
      timer = setTimeout(() => { timer = null; open() }, delay)
    }

    async function checkAndRetry(): Promise<void> {
      let valid: boolean | null = null
      try { valid = await (options.checkSession ?? (async () => (await loadCurrentSession()) !== null))() }
      catch { /* A network failure does not prove session revocation. */ }
      if (!active || ownGeneration !== generation) return
      if (valid === false) {
        disconnect()
        options.onSessionExpired?.()
        return
      }
      schedule()
    }

    function fail(current: RealtimeSocket): void {
      if (!active || socket !== current || ownGeneration !== generation) return
      socket = null
      delivery?.disconnected()
      state.value = 'DISCONNECTED'
      error.value ??= 'Realtime-соединение недоступно. Повторяем подключение.'
      current.close()
      void checkAndRetry()
    }

    function open(): void {
      if (!active || ownGeneration !== generation) return
      const operation = attempt === 0 ? 'realtime.connect' : 'realtime.reconnect'
      const { finish, traceparent, tracestate } = startTracedCompletion(operation)
      pendingConnection = () => finish(true)
      state.value = 'CONNECTING'
      let current: RealtimeSocket
      try {
        const target = url ?? realtimeURL()
        const after = delivery?.cursor()
        current = factory(realtimeTraceURL(after ? `${target}${target.includes('?') ? '&' : '?'}after=${encodeURIComponent(after)}` : target, traceparent, tracestate))
      } catch (cause) {
        finish(true)
        error.value = cause instanceof Error ? cause.message : 'Realtime-соединение недоступно.'
        state.value = 'DISCONNECTED'
        schedule()
        return
      }
      socket = current
      current.onopen = () => { finish(); if (socket === current) { state.value = 'CONNECTED'; error.value = null } }
      current.onmessage = (message) => {
        if (socket !== current) return
        try {
          const event: RealtimeEvent = parseRealtimeEvent(JSON.parse(message.data))
          if (event.kind === 'connection.ready') attempt = 0
          delivery?.accept(event)
        } catch (cause) {
          error.value = cause instanceof Error ? cause.message : 'Некорректное realtime-событие.'
          state.value = 'ERROR'
        }
      }
      current.onerror = () => { finish(true); fail(current) }
      current.onclose = () => { finish(true); fail(current) }
    }
    open()
  }

  function disconnect(): void {
    active = false
    generation++
    if (timer) clearTimeout(timer)
    timer = null
    delivery?.reset()
    delivery = null
    const current = socket
    socket = null
    pendingConnection?.()
    pendingConnection = null
    if (current) { current.onclose = null; current.onerror = null; current.onmessage = null; current.onopen = null; current.close() }
    state.value = 'DISCONNECTED'
    error.value = null
  }

  return { connect, disconnect, error, state }
})
