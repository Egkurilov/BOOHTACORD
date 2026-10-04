import type { VoiceShortcutAction, VoiceShortcutBinding } from './voice_shortcut'
import { bindingMatchesKeyboardEvent, isVoiceShortcutTargetBlocked } from './voice_shortcut'

export interface VoiceShortcutSource {
  addEventListener(type: 'keydown', listener: (event: KeyboardEvent) => void): void
  removeEventListener(type: 'keydown', listener: (event: KeyboardEvent) => void): void
}
export class VoiceShortcuts {
  private readonly onKeyDown = (event: KeyboardEvent): void => {
    if (event.repeat || event.isComposing || event.defaultPrevented || globalThis.document?.visibilityState !== 'visible' || isVoiceShortcutTargetBlocked(event.target)) return
    const action = this.match(event)
    if (!action) return
    event.preventDefault()
    void this.run(action)
  }

  constructor(private readonly source: VoiceShortcutSource, private readonly bindings: () => Record<VoiceShortcutAction, VoiceShortcutBinding | null>, private readonly actions: Record<VoiceShortcutAction, () => Promise<void> | void>, private readonly announce: (action: VoiceShortcutAction) => void = () => undefined) {}

  start(): void { this.source.addEventListener('keydown', this.onKeyDown) }
  stop(): void { this.source.removeEventListener('keydown', this.onKeyDown) }

  private match(event: KeyboardEvent): VoiceShortcutAction | null {
    for (const action of ['microphone', 'deafen'] as const) if (bindingMatchesKeyboardEvent(this.bindings()[action], event)) return action
    return null
  }

  private async run(action: VoiceShortcutAction): Promise<void> {
    try { await this.actions[action](); this.announce(action) } catch { /* voice stores expose user-facing errors */ }
  }
}

