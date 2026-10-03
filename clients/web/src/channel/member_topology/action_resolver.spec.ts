import { describe, expect, it } from 'vitest'

import { memberPermissionDefaults } from '../../authorization/permission_keys'
import { categoryActions, channelActions } from './action_resolver'

describe('member topology action resolver', () => {
  it('shows defaults without exposing destructive actions', () => {
    const permissions = memberPermissionDefaults()
    expect(categoryActions(permissions, true)).toEqual({ createText: true, createVoice: true, delete: false })
    expect(channelActions(permissions, 'VOICE')).toEqual({ delete: false })
  })
})
