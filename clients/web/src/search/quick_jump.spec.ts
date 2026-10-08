import { describe, expect, it } from 'vitest'
import { buildQuickJumpEntries } from './quick_jump'

describe('quick jump entries', () => {
  const channels = [
    { id: 'text-1', name: 'общий', kind: 'TEXT' as const },
    { id: 'voice-1', name: 'голосовой', kind: 'VOICE' as const },
  ]
  const people = [{ id: 'dm-1', displayName: 'Алиса' }]

  it('searches accessible text rooms and people by visible name', () => {
    expect(buildQuickJumpEntries(' ОБЩ ', channels, people)).toEqual([
      { kind: 'CHANNEL', id: 'text-1', title: '#общий', subtitle: 'Текстовый канал' },
    ])
    expect(buildQuickJumpEntries('али', channels, people)).toEqual([
      { kind: 'DIRECT_MESSAGE', id: 'dm-1', title: 'Алиса', subtitle: 'Личное сообщение' },
    ])
  })

  it('does not offer voice channels and includes safe navigation choices when empty', () => {
    expect(buildQuickJumpEntries('', channels, people)).toEqual([
      { kind: 'CHANNEL', id: 'text-1', title: '#общий', subtitle: 'Текстовый канал' },
      { kind: 'DIRECT_MESSAGE', id: 'dm-1', title: 'Алиса', subtitle: 'Личное сообщение' },
    ])
    expect(buildQuickJumpEntries('голосовой', channels, people)).toEqual([])
  })
})
