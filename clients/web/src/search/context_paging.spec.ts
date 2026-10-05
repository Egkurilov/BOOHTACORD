import { expect, it, vi } from 'vitest'
import { createSearchContextController } from './search_context_controller'

it('walks 120 newer rows without replacing the unread anchor or duplicating IDs', async () => {
  const row = (i: number) => ({ id: `${i}`.padStart(3, '0'), deleted: false, createdAt: new Date(i * 1000).toISOString() })
  let page = 0
  const newer = vi.fn(async (_id: string) => { const n = page++ * 20 + 1; return { messages: Array.from({ length: 20 }, (_, i) => row(n+i)), nextCursor: n < 101 ? row(n+19).id : undefined } })
  const context = createSearchContextController(async () => ({ messages: [row(0)] }), { newer })
  await context.open('000')
  for (let i = 0; i < 6; i++) await context.loadNewer()
  expect(context.messages.value).toHaveLength(121)
  expect(context.messages.value[120]?.id).toBe('000')
  expect(context.hasNewer.value).toBe(false)
  expect(newer.mock.calls.map(call => call[0])).toEqual(['000','020','040','060','080','100'])
})

it('drops a forward response after a new context opens and keeps failures retryable', async () => {
  let finish!: (page: { messages: { id: string; deleted: boolean }[] }) => void
  const newer = vi.fn().mockImplementationOnce(() => new Promise(resolve => { finish = resolve })).mockRejectedValueOnce(new Error('503'))
  const context = createSearchContextController(async id => ({ messages: [{ id, deleted: false }] }), { newer })
  await context.open('old'); const pending = context.loadNewer()
  await context.open('new'); finish({ messages: [{ id: 'leaked', deleted: false }] }); await pending
  expect(context.messages.value).toEqual([{ id: 'new', deleted: false }])
  await context.loadNewer()
  expect(context.pagingError.value).toBeTruthy()
  expect(context.hasNewer.value).toBe(true)
})
