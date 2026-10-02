import { createPinia, setActivePinia } from 'pinia'
import { describe, expect, it, vi } from 'vitest'

import { useMessageStore } from './message_store'

describe('text message Unicode boundary', () => {
  it('rejects 8001 emoji without sending or losing the text draft', async () => {
    setActivePinia(createPinia())
    const store = useMessageStore()
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ messages: [] })))
    await store.open('text-1', request)
    request.mockClear()
    await expect(store.send('😀'.repeat(8001), request)).resolves.toBe(false)
    expect(store.error).toContain('8000')
    expect(store.messages).toEqual([])
    expect(request).not.toHaveBeenCalled()
  })
})
