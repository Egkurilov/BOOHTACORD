import { describe, expect, it } from 'vitest'
import { activeMentionQuery, replaceMentionQuery } from './mention_query'

describe('mention autocomplete query', () => {
  it('detects only the unfinished mention at the end of the draft', () => {
    expect(activeMentionQuery('Привет @Da')).toEqual({ start: 7, query: 'Da' })
    expect(activeMentionQuery('@')).toBeNull()
    expect(activeMentionQuery('hello@d')).toBeNull()
  })
  it('replaces the active token and preserves the surrounding draft', () => {
    expect(replaceMentionQuery('Привет @Da', 'Daria')).toBe('Привет @Daria ')
  })
})
