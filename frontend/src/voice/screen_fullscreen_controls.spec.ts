import { describe, expect, it, vi } from 'vitest'

import { createScreenFullscreenControls, type ScreenFullscreenDocument, type ScreenFullscreenTarget } from './screen_fullscreen_controls'

function fullscreenHarness() {
  let listener: (() => void) | undefined
  const target: ScreenFullscreenTarget = { requestFullscreen: vi.fn(async () => { document.fullscreenElement = target; listener?.() }) }
  const document: ScreenFullscreenDocument = {
    fullscreenElement: null,
    exitFullscreen: vi.fn(async () => { document.fullscreenElement = null; listener?.() }),
    addEventListener: vi.fn((_type, callback) => { listener = callback }),
    removeEventListener: vi.fn((_type, callback) => { if (listener === callback) listener = undefined }),
  }
  const onChange = vi.fn()
  const controls = createScreenFullscreenControls(() => target, document, onChange)
  return { controls, document, onChange, target }
}

describe('screen fullscreen controls', () => {
  it('enters the stage and syncs active state on fullscreenchange', async () => {
    const { controls, onChange, target } = fullscreenHarness()
    await expect(controls.toggle()).resolves.toBe(true)
    expect(target.requestFullscreen).toHaveBeenCalledOnce()
    expect(onChange).toHaveBeenLastCalledWith(true)
  })

  it('exits only when this stage currently owns fullscreen', async () => {
    const { controls, document, target } = fullscreenHarness()
    document.fullscreenElement = target
    await expect(controls.toggle()).resolves.toBe(true)
    expect(document.exitFullscreen).toHaveBeenCalledOnce()
  })

  it('syncs changes made by browser controls such as Escape', () => {
    const { controls, document, onChange, target } = fullscreenHarness()
    document.fullscreenElement = target
    controls.sync()
    document.fullscreenElement = null
    controls.sync()
    expect(onChange).toHaveBeenLastCalledWith(false)
  })

  it('reports unavailable fullscreen without invoking browser effects', async () => {
    const target: ScreenFullscreenTarget = {}
    const { document, onChange } = fullscreenHarness()
    const controls = createScreenFullscreenControls(() => target, document, onChange)
    await expect(controls.toggle()).resolves.toBe(false)
    expect(document.exitFullscreen).not.toHaveBeenCalled()
  })

  it('removes its fullscreen listener on dispose', () => {
    const { controls, document } = fullscreenHarness()
    controls.dispose()
    expect(document.removeEventListener).toHaveBeenCalledOnce()
  })
})
