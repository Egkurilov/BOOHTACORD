import { describe, expect, it, vi } from 'vitest'

import { capturePttAssignment } from './ptt_key_capture'

function input(key: string, code: string) {
  return { key, code, preventDefault: vi.fn(), stopPropagation: vi.fn() }
}

describe('PTT key recording keyboard exit', () => {
  it('lets Tab move focus instead of binding Tab', () => {
    const event = input('Tab', 'Tab')
    const stop = vi.fn(); const assign = vi.fn()
    capturePttAssignment(event, stop, assign)
    expect(stop).toHaveBeenCalledOnce()
    expect(assign).not.toHaveBeenCalled()
    expect(event.preventDefault).not.toHaveBeenCalled()
    expect(event.stopPropagation).not.toHaveBeenCalled()
  })

  it('cancels with Escape without closing an enclosing drawer', () => {
    const event = input('Escape', 'Escape')
    const stop = vi.fn(); const assign = vi.fn()
    capturePttAssignment(event, stop, assign)
    expect(stop).toHaveBeenCalledOnce()
    expect(assign).not.toHaveBeenCalled()
    expect(event.preventDefault).toHaveBeenCalledOnce()
    expect(event.stopPropagation).toHaveBeenCalledOnce()
  })

  it('assigns an ordinary key and prevents its browser action', () => {
    const event = input('r', 'KeyR')
    const stop = vi.fn(); const assign = vi.fn()
    capturePttAssignment(event, stop, assign)
    expect(stop).toHaveBeenCalledOnce()
    expect(assign).toHaveBeenCalledExactlyOnceWith('KeyR')
    expect(event.preventDefault).toHaveBeenCalledOnce()
  })
})
