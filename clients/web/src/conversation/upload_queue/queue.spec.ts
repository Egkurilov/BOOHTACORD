import { describe, expect, it, vi } from 'vitest'
import { createManagedUploadQueue } from './queue'
import type { Prepared } from './types'

describe('managed upload queue', () => {
  it('retries only the failed third file and blocks send until resolved', async () => {
    const files = ['one', 'two', 'three'].map(name => new File(['safe'], name+'.txt'))
    const uploaded = (file: File) => ({ id: file.name, originalName: file.name, sizeBytes: file.size })
    const upload = vi.fn().mockImplementationOnce(async (_id, file) => uploaded(file))
      .mockImplementationOnce(async (_id, file) => uploaded(file)).mockRejectedValueOnce(new Error('507'))
      .mockImplementationOnce(async (_id, file) => uploaded(file))
    const emit = vi.fn()
    const queue = createManagedUploadQueue(() => 'a', () => false, emit, upload)
    await queue.upload(files)
    expect(queue.attachments.value).toHaveLength(2)
    expect(queue.blocked.value).toBe(true)
    await queue.retry(queue.items.value[2]!.key)
    expect(upload).toHaveBeenCalledTimes(4)
    expect(upload.mock.calls[3]![1]).toBe(files[2])
    expect(queue.attachments.value).toHaveLength(3)
    expect(queue.blocked.value).toBe(false)
  })

  it('cancels the active transport and ignores its late result after scope switch', async () => {
    let scope = 'a', signal: AbortSignal | undefined
    let finish!: (value: { id: string; originalName: string; sizeBytes: number }) => void
    const upload = vi.fn((_id, _file, control) => { signal = control.signal; return new Promise<Prepared>(resolve => { finish = resolve }) })
    const queue = createManagedUploadQueue(() => scope, () => false, vi.fn(), upload)
    const pending = queue.upload([new File(['safe'], 'one.txt')])
    scope = 'b'; queue.restore([])
    expect(signal?.aborted).toBe(true)
    finish({ id: 'old', originalName: 'one.txt', sizeBytes: 4 })
    await pending
    expect(queue.attachments.value).toEqual([])
    expect(queue.blocked.value).toBe(false)
  })
})
