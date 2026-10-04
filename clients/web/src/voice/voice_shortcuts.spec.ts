import { describe, expect, it, vi } from 'vitest'

import { VoiceShortcuts } from './voice_shortcuts'

function source() {
  let listener: ((event: KeyboardEvent) => void) | undefined
  return { addEventListener: vi.fn((_type: 'keydown', next: (event: KeyboardEvent) => void) => { listener = next }), removeEventListener: vi.fn(), emit: (event: Partial<KeyboardEvent>) => listener?.({ code: 'KeyM', ctrlKey: true, altKey: false, shiftKey: false, metaKey: false, repeat: false, isComposing: false, defaultPrevented: false, target: null, preventDefault: vi.fn(), ...event } as KeyboardEvent) }
}

describe('VoiceShortcuts', () => {
  it('dispatches a matching active-tab shortcut and announces it', async () => {
    vi.stubGlobal('document', { visibilityState: 'visible' })
    const events = source(); const microphone = vi.fn(); const announce = vi.fn()
    const manager = new VoiceShortcuts(events, () => ({ microphone: { code: 'KeyM', ctrlKey: true, altKey: false, shiftKey: false, metaKey: false }, deafen: null }), { microphone, deafen: vi.fn() }, announce)
    manager.start(); events.emit({}); await Promise.resolve()
    expect(microphone).toHaveBeenCalledOnce(); expect(announce).toHaveBeenCalledWith('microphone')
    manager.stop(); expect(events.removeEventListener).toHaveBeenCalledOnce()
  })

  it('ignores repeat, hidden-tab and editable target events', () => {
    const documentState = { visibilityState: 'visible' }
    vi.stubGlobal('document', documentState)
    const events = source(); const microphone = vi.fn(); const manager = new VoiceShortcuts(events, () => ({ microphone: { code: 'KeyM', ctrlKey: true, altKey: false, shiftKey: false, metaKey: false }, deafen: null }), { microphone, deafen: vi.fn() })
    manager.start(); events.emit({ repeat: true }); events.emit({ target: { closest: () => ({}) } as unknown as EventTarget }); documentState.visibilityState = 'hidden'; events.emit({})
    expect(microphone).not.toHaveBeenCalled()
  })
})
