import { describe, expect, it } from 'vitest'

import { exceedsAttachmentCount, MAX_MESSAGE_ATTACHMENTS, MAX_MESSAGE_ATTACHMENT_BYTES } from './attachment_limits'

describe('conversation attachment limits', () => {
  it('shares the ten-file and 25 MB boundaries across TEXT and DM upload queues', () => {
    expect(MAX_MESSAGE_ATTACHMENTS).toBe(10)
    expect(MAX_MESSAGE_ATTACHMENT_BYTES).toBe(25_000_000)
    expect(exceedsAttachmentCount(0, 0, 10)).toBe(false)
    expect(exceedsAttachmentCount(8, 1, 2)).toBe(true)
    expect(exceedsAttachmentCount(5, 2, 4)).toBe(true)
  })
})
