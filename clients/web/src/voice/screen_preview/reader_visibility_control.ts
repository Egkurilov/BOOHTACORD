import { screenPreviewPollIntervalMs, screenPreviewRetryDelay } from './reader_retry'
import type { ScreenPreviewHint } from './client'
import type { ScreenPreviewVisibilitySource } from './visibility'

export interface ScreenPreviewReaderState {
  hint: ScreenPreviewHint
  revision: number
  pending: number
  running: boolean
  poll: boolean
  visible: boolean
  failures: number
  timer?: ReturnType<typeof setTimeout>
}

export function refreshScreenPreviewVisibility(
  states: Map<string, ScreenPreviewReaderState>,
  visibility: ScreenPreviewVisibilitySource,
  pump: (leaseId: string, state: ScreenPreviewReaderState) => void,
): void {
  states.forEach((state, leaseId) => {
    const visible = visibility.isVisible(leaseId)
    if (visible === state.visible) return
    state.visible = visible
    if (!visible) {
      if (state.timer) clearTimeout(state.timer)
      state.timer = undefined
      state.poll = true
      return
    }
    if (state.timer) clearTimeout(state.timer)
    state.timer = undefined
    state.poll = true
    if (!state.running) pump(leaseId, state)
  })
}

export function scheduleScreenPreviewPoll(
  leaseId: string,
  state: ScreenPreviewReaderState,
  states: Map<string, ScreenPreviewReaderState>,
  visibility: ScreenPreviewVisibilitySource,
  pump: (leaseId: string, state: ScreenPreviewReaderState) => void,
  random: () => number,
): void {
  const delay = state.failures ? screenPreviewRetryDelay(state.failures, random) : screenPreviewPollIntervalMs
  state.timer = setTimeout(() => {
    if (states.get(leaseId) !== state) return
    state.timer = undefined
    if (!visibility.isVisible(leaseId)) { state.visible = false; state.poll = true; return }
    state.poll = true
    pump(leaseId, state)
  }, delay)
}
