import { describe, expect, it } from 'vitest'

import { directMessageAttachmentDownloadUrl, directMessageAttachmentPreviewUrl } from './direct_message_attachment_url'

describe('private DM attachment URLs', () => {
  it('builds encoded same-origin download and raster-preview paths', () => {
    expect(directMessageAttachmentDownloadUrl('dm/a', 'file ?#')).toBe('/api/v1/direct-messages/dm%2Fa/attachments/file%20%3F%23')
    expect(directMessageAttachmentPreviewUrl('dm/a', 'file ?#')).toBe('/api/v1/direct-messages/dm%2Fa/attachments/file%20%3F%23/preview')
  })

  it('rejects absent target IDs', () => {
    expect(() => directMessageAttachmentDownloadUrl('', 'file')).toThrow('Некорректное вложение')
    expect(() => directMessageAttachmentPreviewUrl('dm', '')).toThrow('Некорректное вложение')
  })
})
