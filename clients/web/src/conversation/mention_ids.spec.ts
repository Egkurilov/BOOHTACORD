import { describe, expect, it } from 'vitest'

import { addMentionId, parseMentionIds } from './mention_ids'

describe('mention IDs', () => {
  it('rejects malformed server mention lists and duplicate IDs', () => {
    expect(parseMentionIds(['user-2'])).toEqual(['user-2'])
    expect(() => parseMentionIds(undefined)).toThrow('упомин')
    expect(() => parseMentionIds(['user-2', 'user-2'])).toThrow('упомин')
  })

  it('selects stable IDs without self, duplicates or name-based identity', () => {
    expect(addMentionId([], 'user-2', 'user-1')).toEqual(['user-2'])
    expect(addMentionId(['user-2'], 'user-2', 'user-1')).toEqual(['user-2'])
    expect(addMentionId(['user-2'], 'user-1', 'user-1')).toEqual(['user-2'])
  })
})
