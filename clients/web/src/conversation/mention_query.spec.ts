import { describe, expect, it } from 'vitest'
import { activeMentionQuery, replaceMentionQuery } from './mention_query'

describe('mention autocomplete query', () => {
  it('detects an unfinished mention, including the empty query opened by the @ action', () => {
    expect(activeMentionQuery('Привет @Da')).toEqual({ start: 7, query: 'Da' })
    expect(activeMentionQuery('@')).toEqual({ start: 0, query: '' })
    expect(activeMentionQuery('hello@d')).toBeNull()
  })
  it('replaces the active token and preserves the surrounding draft', () => {
    expect(replaceMentionQuery('Привет @Da', 'Daria')).toBe('Привет @Daria ')
    expect(replaceMentionQuery('@', 'Daria')).toBe('@Daria ')
  })
})
