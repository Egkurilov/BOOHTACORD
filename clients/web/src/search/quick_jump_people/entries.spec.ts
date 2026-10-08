import { expect, it } from 'vitest'
import { quickJumpPeople } from './entries'
import { buildQuickJumpEntries } from '../quick_jump'

it('deduplicates existing private dialogs by participant and adds eligible members', () => {
  const entries = quickJumpPeople([{ id: 'dm', otherParticipantId: 'alice', otherParticipantDisplayName: 'Алиса' }],
    [{ id: 'alice', displayName: 'Алиса новая' }, { id: 'bob', displayName: 'Боб' }])
  expect(entries).toEqual([{ id: 'dm', displayName: 'Алиса новая', kind: 'DIRECT_MESSAGE' },
    { id: 'bob', displayName: 'Боб', kind: 'MEMBER' }])
  expect(buildQuickJumpEntries('Боб', [], entries)).toEqual([
    { id: 'bob', title: 'Боб', kind: 'MEMBER', subtitle: 'Участник гильдии' },
  ])
})

it('preserves authorized existing DM choices while candidate inventory is empty', () => {
  expect(quickJumpPeople([{ id: 'dm', otherParticipantId: 'alice', otherParticipantDisplayName: 'Алиса' }], [])).
    toEqual([{ id: 'dm', displayName: 'Алиса', kind: 'DIRECT_MESSAGE' }])
})
