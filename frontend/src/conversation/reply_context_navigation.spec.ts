import { describe, expect, it, vi } from 'vitest'

import { navigateToReplyTarget } from './reply_context_navigation'

function row(messageId: string, scrollIntoView = vi.fn()): HTMLElement {
  return {
    dataset: { messageId },
    scrollIntoView,
  } as unknown as HTMLElement
}

function list(...rows: HTMLElement[]): HTMLElement {
  return {
    querySelectorAll: vi.fn(() => rows),
  } as unknown as HTMLElement
}

describe('reply context navigation', () => {
  it('scrolls a loaded target into view without opening remote context', () => {
    const scrollIntoView = vi.fn()
    const target = row('target-1', scrollIntoView)
    const root = list(row('other'), target)
    const openMissingContext = vi.fn()

    navigateToReplyTarget(root, 'target-1', openMissingContext)

    expect(scrollIntoView).toHaveBeenCalledWith({ behavior: 'smooth', block: 'center' })
    expect(openMissingContext).not.toHaveBeenCalled()
  })

  it('opens bounded context when the target is outside the loaded window', () => {
    const openMissingContext = vi.fn()

    navigateToReplyTarget(list(row('other')), 'older-target', openMissingContext)

    expect(openMissingContext).toHaveBeenCalledOnce()
  })

  it('opens bounded context when the history list is not mounted', () => {
    const openMissingContext = vi.fn()

    navigateToReplyTarget(null, 'target-1', openMissingContext)

    expect(openMissingContext).toHaveBeenCalledOnce()
  })
})
