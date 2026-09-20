import { defineStore } from 'pinia'
import { ref } from 'vue'

import { parseRealtimeEvent, realtimeURL } from './realtime_client'

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

  function connect(onResync: () => void, factory: RealtimeSocketFactory = (url) => new WebSocket(url), url?: string): void {
    if (socket) return
    state.value = 'CONNECTING'
    error.value = null
    socket = factory(url ?? realtimeURL())
    socket.onopen = () => { state.value = 'CONNECTED' }
    socket.onmessage = (event) => {
      try {
        if (parseRealtimeEvent(JSON.parse(event.data)).kind === 'connection.resync_required') onResync()
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
