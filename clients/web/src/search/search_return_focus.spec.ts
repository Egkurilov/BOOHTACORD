import { describe, expect, it } from 'vitest'
import { searchReturnFocusTarget } from './search_return_focus'

const target = (isConnected = true) => ({ isConnected }) as HTMLElement

describe('search focus restoration', () => {
  it('returns to the search trigger when Ctrl+K started from the document body', () => {
    const body = target()
    const html = target()
    const trigger = target()
    expect(searchReturnFocusTarget(body, trigger, body, html)).toBe(trigger)
    expect(searchReturnFocusTarget(html, trigger, body, html)).toBe(trigger)
  })

  it('restores a connected prior control, but not one removed while searching', () => {
    const body = target()
    const html = target()
    const trigger = target()
    const previous = target()
    expect(searchReturnFocusTarget(previous, trigger, body, html)).toBe(previous)
    expect(searchReturnFocusTarget(target(false), trigger, body, html)).toBe(trigger)
  })
})
