import { describe, expect, it, vi } from 'vitest'

import { useTextAttachmentQueue } from './text_attachment_queue'

describe('TEXT attachment queue', () => {
  it('hydrates only prepared IDs for the reopened channel', () => {
    const prepared = [{ id: 'saved-id', originalName: 'image.png', sizeBytes: 4 }]
    const queue = useTextAttachmentQueue(() => 'text-1', () => false, vi.fn(), vi.fn(), prepared)
    expect(queue.attachments.value).toEqual(prepared)
    queue.clear()
    expect(queue.attachments.value).toEqual([])
  })
  it('retains the failed file after 507 and retries that same file once after capacity returns', async () => {
    const file = new File(['safe'], 'safe.txt', { type: 'text/plain' })
    const upload = vi.fn().mockRejectedValueOnce(new Error('507: INSUFFICIENT_STORAGE'))
      .mockResolvedValueOnce({ id: 'attachment-1', originalName: file.name, sizeBytes: file.size })
    const emit = vi.fn()
    const queue = useTextAttachmentQueue(() => 'text-1', () => false, emit, upload)

    await queue.upload([file])
    expect(queue.error.value).toContain('507')
    expect(queue.failed.value).toEqual([file])
    expect(queue.attachments.value).toEqual([])

    await queue.retry()
    expect(upload).toHaveBeenCalledTimes(2)
    expect(upload).toHaveBeenNthCalledWith(2, 'text-1', file)
    expect(queue.failed.value).toEqual([])
    expect(queue.attachments.value).toEqual([{ id: 'attachment-1', originalName: file.name, sizeBytes: file.size }])
    expect(emit).toHaveBeenCalledWith('change', queue.attachments.value)
  })

  it('does not expose a completed upload in a different channel', async () => {
    let channel = 'text-1'
    let complete!: (value: { id: string; originalName: string; sizeBytes: number }) => void
    const upload = vi.fn().mockImplementation(() => new Promise(resolve => { complete = resolve }))
    const emit = vi.fn()
    const queue = useTextAttachmentQueue(() => channel, () => false, emit, upload)
    const inFlight = queue.upload([new File(['safe'], 'safe.txt')])
    channel = 'text-2'
    queue.clear()
    complete({ id: 'old', originalName: 'safe.txt', sizeBytes: 4 })
    await inFlight
    expect(queue.attachments.value).toEqual([])
    expect(queue.failed.value).toEqual([])
  })
})
