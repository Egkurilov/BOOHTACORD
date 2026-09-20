import { describe, expect, it } from 'vitest'

import { textMessageAttachmentPreviewUrl } from './text_message_attachment_preview_url'

describe('text message attachment preview URL', () => {
  it('builds only an encoded same-origin protected preview path', () => {
    expect(textMessageAttachmentPreviewUrl('channel/a', 'file ?#')).toBe('/api/v1/channels/channel%2Fa/attachments/file%20%3F%23/preview')
  })

  it('rejects missing identifiers before a template can create a broad route', () => {
    expect(() => textMessageAttachmentPreviewUrl('', 'file-1')).toThrow('Некорректное вложение')
    expect(() => textMessageAttachmentPreviewUrl('channel-1', '')).toThrow('Некорректное вложение')
  })
})
