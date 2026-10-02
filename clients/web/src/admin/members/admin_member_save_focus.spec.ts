import { describe, expect, it, vi } from 'vitest'

import { restoreAdminSaveFocus } from './admin_member_save_focus'

function trigger(connected = true) {
  return { isConnected: connected, focus: vi.fn() }
}

describe('administrator save focus restoration', () => {
  it('restores the keyboard trigger after a disabled save returns focus to body', () => {
    const button = trigger()
    const body = {}
    expect(restoreAdminSaveFocus(button, true, body, body)).toBe(true)
    expect(button.focus).toHaveBeenCalledOnce()
  })

  it('does not steal focus moved elsewhere during the request', () => {
    const button = trigger()
    const body = {}
    expect(restoreAdminSaveFocus(button, true, {}, body)).toBe(false)
    expect(button.focus).not.toHaveBeenCalled()
  })

  it('ignores an unmounted control or a save triggered without focus', () => {
    const button = trigger(false)
    const body = {}
    expect(restoreAdminSaveFocus(button, true, body, body)).toBe(false)
    expect(restoreAdminSaveFocus(trigger(), false, body, body)).toBe(false)
  })
})
