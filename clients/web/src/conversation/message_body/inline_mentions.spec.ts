import { describe, expect, it } from 'vitest'

import { decorateMessageMentions } from './inline_mentions'

describe('message mention presentation', () => {
  const daria = { id: 'daria-id', name: 'Daria' }

  it('styles only the recipient named in the message metadata', () => {
    const result = decorateMessageMentions('@Daria Отлично, @Друг!', [daria])
    expect(result.blocks[0]).toMatchObject({ kind: 'PARAGRAPH', spans: [
      { kind: 'MENTION', value: '@Daria', id: 'daria-id' },
      { kind: 'TEXT', value: ' Отлично, @Друг!' },
    ] })
    expect(result.unmatchedIds).toEqual([])
  })

  it('keeps the recipient summary when a renamed or code-only mention is not inline', () => {
    expect(decorateMessageMentions('Привет', [daria]).unmatchedIds).toEqual(['daria-id'])
    expect(decorateMessageMentions('```@Daria```', [daria]).unmatchedIds).toEqual(['daria-id'])
  })

  it('does not style email fragments, longer usernames or ambiguous equal names', () => {
    const body = 'mail@Daria.test @Darian @Daria'
    const decorated = decorateMessageMentions(body, [daria])
    expect(decorated.blocks[0]).toMatchObject({ kind: 'PARAGRAPH', spans: [
      { kind: 'TEXT', value: 'mail@Daria.test @Darian ' },
      { kind: 'MENTION', value: '@Daria', id: 'daria-id' },
    ] })
    expect(decorateMessageMentions('@Daria', [daria, { id: 'other-id', name: 'Daria' }]).unmatchedIds).toEqual(['daria-id', 'other-id'])
  })
})
