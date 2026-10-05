import { reconnectDelay } from '../reconnect_policy'
export function createReconnectSchedule(open: () => void, random?: () => number) {
  let timer: ReturnType<typeof setTimeout> | null = null
  let attempt = 0
  function stop(): void { if (timer) clearTimeout(timer); timer = null }
  return {
    attempt: () => attempt,
    ready: () => { attempt = 0 },
    stop,
    schedule(): void {
      if (timer) return
      timer = setTimeout(() => { timer = null; open() }, reconnectDelay(attempt++, random))
    },
  }
}
