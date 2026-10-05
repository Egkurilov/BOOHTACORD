import { expect, it } from 'vitest'
import { capture, restore } from './dom'
import { loadPosition, savePosition } from './memory'
import { clearDraftMemory, draftKey } from '../draft_memory'

it('preserves the first visible row offset, even after rows are prepended', () => {
  let top = 85
  const row = { dataset: { messageId: 'anchor' }, getBoundingClientRect: () => ({ top, bottom: top + 40 }) }
  const viewport = { clientHeight: 200, scrollTop: 30, querySelectorAll: () => [row], getBoundingClientRect: () => ({ top: 100 }) } as unknown as HTMLElement
  const position = capture(viewport)!
  expect(position).toEqual({ id: 'anchor', offset: -15 })
  top = 145
  expect(restore(viewport, position)).toBe(true)
  expect(viewport.scrollTop).toBe(90)
  expect(restore(viewport, { id: 'deleted', offset: 0 })).toBe(false)
})

it('isolates account/conversation positions and clears them on session epoch change', () => {
  const key = draftKey('a', 'CHANNEL', 'one')
  savePosition(key, { id: 'anchor', offset: 15 })
  expect(loadPosition(draftKey('b', 'CHANNEL', 'one'))).toBeNull()
  expect(loadPosition(draftKey('a', 'CHANNEL', 'two'))).toBeNull()
  expect(loadPosition(key)).toEqual({ id: 'anchor', offset: 15 })
  clearDraftMemory()
  expect(loadPosition(key)).toBeNull()
})
