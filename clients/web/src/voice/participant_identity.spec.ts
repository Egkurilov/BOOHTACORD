import { describe, expect, it } from 'vitest'

import { accountIdFromMetadata } from './participant_identity'

describe('participant identity', () => {
  it('accepts only a signed account UUID metadata value', () => {
    expect(accountIdFromMetadata('account:11111111-1111-4111-8111-111111111111')).toBe('11111111-1111-4111-8111-111111111111')
    expect(accountIdFromMetadata('account:lease-1')).toBeNull()
    expect(accountIdFromMetadata('voice-lease:lease-1')).toBeNull()
  })
})
