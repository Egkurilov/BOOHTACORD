export interface RealtimeSocket {
  close(): void
  onclose: ((event: CloseEvent) => void) | null
  onerror: ((event: Event) => void) | null
  onmessage: ((event: MessageEvent<string>) => void) | null
  onopen: ((event: Event) => void) | null
}

export type RealtimeSocketFactory = (url: string) => RealtimeSocket

export interface RealtimeConnectOptions {
  checkSession?: () => Promise<boolean>
  onRecovery?: () => void | Promise<void>
  onSessionExpired?: () => void
  random?: () => number
}
