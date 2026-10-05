import { expect, it, vi } from 'vitest'
import { createManagedUploadQueue } from './queue'
import { createComposerDrop } from './drop'
import type { Prepared, UploadControl } from './types'

it('queues ten maximum-sized files sequentially, reports progress and preserves prepared IDs', async () => {
  let resolve!: (value: Prepared) => void, control!: UploadControl
  const upload = vi.fn((_id: string, file: File, next: UploadControl) => {
    control = next
    return new Promise<Prepared>(done => { resolve = done })
  })
  const emit = vi.fn(), queue = createManagedUploadQueue(() => 'a', () => false, emit, upload)
  const files = Array.from({ length: 10 }, (_, i) => new File([new Uint8Array(25_000_000)], `${i}.bin`))
  const pending = queue.upload(files)
  control.onProgress(100)
  expect(queue.items.value[0]?.progress).toBe(99)
  expect(queue.attachments.value).toHaveLength(0)
  await queue.upload([new File(['extra'], 'extra')])
  expect(upload).toHaveBeenCalledTimes(1)
  for (let i = 0; i < 10; i++) {
    resolve({ id: `${i}`, originalName: files[i]!.name, sizeBytes: files[i]!.size })
    await Promise.resolve(); await Promise.resolve()
  }
  await pending
  expect(upload).toHaveBeenCalledTimes(10)
  expect(queue.attachments.value).toHaveLength(10)
  queue.restore(queue.attachments.value)
  expect(queue.items.value.every(item => item.status === 'done' && !item.file)).toBe(true)
  expect(emit).toHaveBeenLastCalledWith('pending', false)
})

it('intercepts files only and never uploads into an inactive composer', () => {
  const add = vi.fn(), preventDefault = vi.fn(), stopPropagation = vi.fn()
  const drop = createComposerDrop(add, () => false)
  drop.onDrop({ dataTransfer: { files: [] }, preventDefault, stopPropagation } as unknown as DragEvent)
  expect(preventDefault).not.toHaveBeenCalled()
  drop.onDrop({ dataTransfer: { files: [new File(['x'], 'x')] }, preventDefault, stopPropagation } as unknown as DragEvent)
  expect(preventDefault).toHaveBeenCalledOnce()
  expect(add).not.toHaveBeenCalled()
})
