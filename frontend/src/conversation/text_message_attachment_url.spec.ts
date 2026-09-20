import { describe, expect, it } from 'vitest'

import { textMessageAttachmentDownloadUrl } from './text_message_attachment_url'

describe('text message attachment URL', () => {
  it('builds only an encoded same-origin attachment path', () => {
    expect(textMessageAttachmentDownloadUrl('channel/a', 'file ?#')).toBe('/api/v1/channels/channel%2Fa/attachments/file%20%3F%23')
  })

  it('rejects missing identifiers before a template can create a broad route', () => {
    expect(() => textMessageAttachmentDownloadUrl('', 'file-1')).toThrow('Некорректное вложение')
    expect(() => textMessageAttachmentDownloadUrl('channel-1', '')).toThrow('Некорректное вложение')
  })
})
