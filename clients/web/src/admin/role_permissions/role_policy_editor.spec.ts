import { describe, expect, it } from 'vitest'

import { changed, newlyGrantedDeletes } from './role_policy_editor'
import { memberPermissionDefaults } from '../../authorization/permission_keys'

describe('role policy editor', () => {
  it('detects only changed values and new delete grants', () => {
    const baseline = memberPermissionDefaults()
    expect(changed(baseline, { ...baseline })).toBe(false)
    const draft = { ...baseline, 'channel.voice.delete': true, 'channel.text.create': false }
    expect(changed(baseline, draft)).toBe(true)
    expect(newlyGrantedDeletes(baseline, draft)).toEqual(['channel.voice.delete'])
  })
})
