import { expect, it } from 'vitest'
import { createQuickJumpPeople } from './state'
import type { DirectMessageCandidatePage } from '../../direct_message/direct_message_candidate_client'

it('loads bounded pages, deduplicates and preserves accepted data on a failed next page', async () => {
  let calls = 0
  const state = createQuickJumpPeople(async after => {
    calls++
    if (!after) return { candidates: [{ id: 'a', displayName: 'А' }], nextAfter: 'a' }
    if (calls === 2) throw Error('denied')
    return { candidates: [{ id: 'a', displayName: 'А' }, { id: 'b', displayName: 'Б' }] }
  })
  await state.refresh()
  await state.next()
  expect(state.people.value).toHaveLength(1)
  expect(state.error.value).toBeTruthy()
  await state.next()
  expect(state.people.value).toHaveLength(2)
  expect(state.after.value).toBeUndefined()
  state.dispose()
})

it('disposal prevents an old account response from restoring private candidates', async () => {
  let resolve!: (page: DirectMessageCandidatePage) => void
  const state = createQuickJumpPeople(() => new Promise(r => { resolve = r }))
  const pending = state.refresh()
  state.dispose()
  resolve({ candidates: [{ id: 'a', displayName: 'А' }] })
  await pending
  expect(state.people.value).toEqual([])
  expect(state.loading.value).toBe(false)
})
