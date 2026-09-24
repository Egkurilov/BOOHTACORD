import { defineStore } from 'pinia'
import { ref } from 'vue'

import { parseRealtimeEvent, realtimeURL, type RealtimeEvent } from './realtime_client'

export type RealtimeState = 'IDLE' | 'CONNECTING' | 'CONNECTED' | 'DISCONNECTED' | 'ERROR'
export interface RealtimeSocket {
  close(): void
  onclose: ((event: CloseEvent) => void) | null
  onerror: ((event: Event) => void) | null
  onmessage: ((event: MessageEvent<string>) => void) | null
  onopen: ((event: Event) => void) | null
}
export type RealtimeSocketFactory = (url: string) => RealtimeSocket

export const useRealtimeStore = defineStore('realtime', () => {
  const state = ref<RealtimeState>('IDLE')
  const error = ref<string | null>(null)
  let socket: RealtimeSocket | null = null

  function connect(onResync: (event: RealtimeEvent) => void, factory: RealtimeSocketFactory = (url) => new WebSocket(url), url?: string): void {
    if (socket) return
    state.value = 'CONNECTING'
    error.value = null
    socket = factory(url ?? realtimeURL())
    socket.onopen = () => { state.value = 'CONNECTED' }
    socket.onmessage = (event) => {
      try {
        const message = parseRealtimeEvent(JSON.parse(event.data))
        if (message.kind === 'message.created' && (Object.keys(message.payload).length !== 2 || typeof message.payload.channel_id !== 'string' || !message.payload.channel_id || typeof message.payload.message_id !== 'string' || !message.payload.message_id)) throw new Error('Некорректное realtime-событие.')
        if (message.kind === 'connection.resync_required' || message.kind === 'presence.snapshot' || message.kind === 'presence.changed' || message.kind === 'message.created') onResync(message)
      } catch (cause) {
        state.value = 'ERROR'
        error.value = cause instanceof Error ? cause.message : 'Некорректное realtime-событие.'
      }
    }
    socket.onerror = () => {
      state.value = 'ERROR'
      error.value = 'Realtime-соединение недоступно.'
    }
    socket.onclose = () => {
      socket = null
      if (state.value !== 'ERROR') state.value = 'DISCONNECTED'
    }
  }

  function disconnect(): void {
    if (!socket) return
    state.value = 'DISCONNECTED'
    socket.close()
    socket = null
  }

  return { connect, disconnect, error, state }
})
