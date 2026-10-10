import { describe, expect, it, vi } from 'vitest'

import { navigateWithSettingsGuard } from './settings_exit_guard'

describe('settings exit guard', () => {
  it('leaves immediately when there are no unsaved changes', async () => {
    const confirmDiscard = vi.fn(async () => false)
    const navigate = vi.fn()

    await expect(navigateWithSettingsGuard(false, confirmDiscard, navigate)).resolves.toBe(true)
    expect(confirmDiscard).not.toHaveBeenCalled()
    expect(navigate).toHaveBeenCalledOnce()
  })

  it('keeps the settings open when the user cancels discarding edits', async () => {
    const navigate = vi.fn()
    await expect(navigateWithSettingsGuard(true, async () => false, navigate)).resolves.toBe(false)
    expect(navigate).not.toHaveBeenCalled()
  })

  it('allows leaving after the user explicitly confirms discarding edits', async () => {
    const navigate = vi.fn()
    await expect(navigateWithSettingsGuard(true, async () => true, navigate)).resolves.toBe(true)
    expect(navigate).toHaveBeenCalledOnce()
  })
})
