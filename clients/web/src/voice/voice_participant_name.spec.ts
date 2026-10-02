import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useAuthorDirectory } from '../identity/author_directory'
import { voiceParticipantName } from './voice_participant_name'

const accountId = '11111111-1111-4111-8111-111111111111'

describe('voice participant name', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('keeps the LiveKit name until an authenticated member lookup succeeds, then uses the current profile name', async () => {
    const authors = useAuthorDirectory()
    expect(voiceParticipantName(authors, accountId, 'Старое имя')).toBe('Старое имя')
    expect(voiceParticipantName(authors, accountId, undefined)).toBeUndefined()
    await authors.ensure(accountId, async () => new Response(JSON.stringify({ user_id: accountId, login: 'member', display_name: 'Новый ник', role: 'MEMBER' })))
    expect(voiceParticipantName(authors, accountId, 'Старое имя')).toBe('Новый ник')
    expect(voiceParticipantName(authors, accountId, undefined)).toBe('Новый ник')
  })

  it('does not replace a token name with an unrelated or unavailable profile', async () => {
    const authors = useAuthorDirectory()
    await authors.ensure(accountId, async () => new Response(JSON.stringify({ user_id: '22222222-2222-4222-8222-222222222222', login: 'member', display_name: 'Чужой ник', role: 'MEMBER' })))
    expect(voiceParticipantName(authors, accountId, 'Из токена')).toBe('Из токена')
    expect(voiceParticipantName(authors, null, 'Из токена')).toBe('Из токена')
    await authors.ensure(accountId, async () => new Response(JSON.stringify({ user_id: accountId, login: 'member', display_name: ' ', role: 'MEMBER' })), true)
    expect(voiceParticipantName(authors, accountId, 'Из токена')).toBe('Из токена')
  })

  it('treats a blank LiveKit name as absent', () => {
    expect(voiceParticipantName(useAuthorDirectory(), accountId, '   ')).toBeUndefined()
  })
})
