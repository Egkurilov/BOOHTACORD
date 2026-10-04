import type { VoiceShortcutAction, VoiceShortcutBinding } from './model'
import { bindingMatchesKeyboardEvent, isVoiceShortcutTargetBlocked } from './model'

export interface VoiceShortcutSource {
  addEventListener(type: 'keydown', listener: (event: KeyboardEvent) => void): void
  removeEventListener(type: 'keydown', listener: (event: KeyboardEvent) => void): void
}
export class VoiceShortcuts {
  private started = false
  private busy = false
  private generation = 0
  private pending: object | null = null
  private readonly onKeyDown = (event: KeyboardEvent): void => {
    if (!this.started || this.busy || globalThis.document?.hasFocus?.() === false || event.repeat || event.isComposing || event.defaultPrevented || globalThis.document?.visibilityState !== 'visible' || isVoiceShortcutTargetBlocked(event.target)) return
    const action = this.match(event)
    if (!action) return
    event.preventDefault()
    void this.run(action)
  }

  constructor(private readonly source: VoiceShortcutSource, private readonly bindings: () => Record<VoiceShortcutAction, VoiceShortcutBinding | null>, private readonly actions: Record<VoiceShortcutAction, () => Promise<void | 'applied' | 'blocked'> | void>, private readonly announce: (action: VoiceShortcutAction, result?: 'applied' | 'blocked') => void = () => undefined) {}

  invalidate(): void { this.generation++ }
  start(): void { if (this.started) return; this.started = true; this.source.addEventListener('keydown', this.onKeyDown) }
  stop(): void { this.started = false; this.generation++; this.busy = false; this.pending = null; this.source.removeEventListener('keydown', this.onKeyDown) }

  private match(event: KeyboardEvent): VoiceShortcutAction | null {
    for (const action of ['microphone', 'deafen'] as const) if (bindingMatchesKeyboardEvent(this.bindings()[action], event)) return action
    return null
  }

  private async run(action: VoiceShortcutAction): Promise<void> {
    const generation = this.generation
    const pending = this.pending = {}
    this.busy = true
    try {
      const result = await this.actions[action]()
      if (!this.started || generation !== this.generation) return
      if (result) this.announce(action, result)
      else this.announce(action)
    } catch { /* existing stores expose errors */ }
    finally { if (pending === this.pending) { this.busy = false; this.pending = null } }
  }
}

