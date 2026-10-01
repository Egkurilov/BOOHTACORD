import { describe, expect, it } from 'vitest'

import { chronologicalDatedMessages } from './history_dates'
import { groupChronologicalMessages } from './message_grouping'

const message = (id: string, createdAt: string, extras: Record<string, unknown> = {}) => ({
  id, authorId: 'author', createdAt, ...extras,
})

describe('consecutive message grouping', () => {
  it('groups the same author at exactly five minutes but not after a longer gap or another author', () => {
    const entries = chronologicalDatedMessages([
      message('different', '2026-09-25T10:11:00Z', { authorId: 'other' }),
      message('late', '2026-09-25T10:10:01Z'),
      message('within', '2026-09-25T10:05:00Z'),
      message('first', '2026-09-25T10:00:00Z'),
    ])
    expect(groupChronologicalMessages(entries).map(({ grouped }) => grouped)).toEqual([false, true, false, false])
  })

  it('breaks groups at date, reply, system, deleted and pending boundaries', () => {
    const entries = [
      { message: message('first', '2026-09-24T23:59:00Z'), dateLabel: '24 сентября' },
      { message: message('new-day', '2026-09-25T00:00:00Z'), dateLabel: '25 сентября' },
      { message: message('reply', '2026-09-25T00:01:00Z', { replyToId: 'first' }) },
      { message: message('after-reply', '2026-09-25T00:02:00Z') },
      { message: message('system', '2026-09-25T00:03:00Z', { system: true }) },
      { message: message('after-system', '2026-09-25T00:04:00Z') },
      { message: message('deleted', '2026-09-25T00:05:00Z', { deleted: true }) },
      { message: message('after-deleted', '2026-09-25T00:06:00Z') },
      { message: message('pending', '2026-09-25T00:07:00Z', { sendStatus: 'sending' }) },
      { message: message('after-pending', '2026-09-25T00:08:00Z') },
    ]
    expect(groupChronologicalMessages(entries).map(({ grouped }) => grouped)).toEqual(Array(10).fill(false))
  })
})
