import { expect, it, vi } from 'vitest'
import { ref } from 'vue'
import { createLoadedRevisionRefresh } from './loaded'
it('refreshes multiple old-page edits/tombstones with one sequential page walk', async () => {
  const messages = ref([{ id: 'old-a', revision: 1 }, { id: 'old-b', revision: 1 }])
  let concurrent = 0, maximum = 0
  const load = vi.fn(async (_id: string, before?: string) => {
    concurrent++; maximum = Math.max(maximum, concurrent)
    await Promise.resolve(); concurrent--
    return before ? { messages: [{ id: 'old-a', revision: 2 }, { id: 'old-b', revision: 3, deleted: true }] }
      : { messages: [{ id: 'new', revision: 1 }], nextCursor: 'older' }
  })
  const revisions = createLoadedRevisionRefresh({ messages, resourceId: ref('room'), version: () => 1,
    load, merge: incoming => { messages.value = incoming }, error: ref(null), fallback: 'failed' })
  await revisions.refreshMessages(['old-a', 'old-b'])
  expect(load).toHaveBeenCalledTimes(2)
  expect(maximum).toBe(1)
  expect(messages.value).toEqual([{ id: 'old-a', revision: 2 }, { id: 'old-b', revision: 3, deleted: true }])
})
it('ignores a late page after switching resources', async () => {
  const resourceId = ref('first')
  const merge = vi.fn()
  const revisions = createLoadedRevisionRefresh({ messages: ref([{ id: 'old', revision: 1 }]), resourceId,
    version: () => 1, load: async () => { resourceId.value = 'second'; return { messages: [{ id: 'old', revision: 2 }] } },
    merge, error: ref(null), fallback: 'failed' })
  await revisions.refreshMessages(['old'])
  expect(merge).not.toHaveBeenCalled()
})
