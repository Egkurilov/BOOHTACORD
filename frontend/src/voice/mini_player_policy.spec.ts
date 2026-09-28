import { describe, expect, it } from 'vitest'

import { miniPlayerVisible, screenViewerMounted } from './mini_player_policy'

describe('opt-in mini player policy', () => {
  it('keeps one viewer after navigation only when the remote stream was pinned', () => {
    expect(screenViewerMounted(true, false, 'stream-a', 'voice-a')).toBe(true)
    expect(miniPlayerVisible(true, false, 'stream-a', 'voice-a')).toBe(true)
    expect(screenViewerMounted(false, false, 'stream-a', 'voice-a')).toBe(false)
    expect(miniPlayerVisible(true, true, 'stream-a', 'voice-a')).toBe(false)
  })

  it('closes on leave, revocation or ended selection', () => {
    expect(screenViewerMounted(true, false, null, 'voice-a')).toBe(false)
    expect(screenViewerMounted(true, false, 'stream-a', null)).toBe(false)
    expect(miniPlayerVisible(true, false, null, 'voice-a')).toBe(false)
  })
})
