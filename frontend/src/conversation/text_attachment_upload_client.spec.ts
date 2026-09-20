import { describe, expect, it, vi } from 'vitest'

import { uploadTextAttachment } from './text_attachment_upload_client'

describe('text attachment upload client', () => {
  it('uploads one file through the authenticated same-origin endpoint', async () => {
    const file = new File(['note'], 'notes.txt', { type: 'text/plain' })
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      id: 'attachment-1', original_name: 'notes.txt', byte_size: 4,
    }), { status: 201 }))

    await expect(uploadTextAttachment('text-1', file, request)).resolves.toEqual({
      id: 'attachment-1', originalName: 'notes.txt', sizeBytes: 4,
    })
    expect(request).toHaveBeenCalledWith(
      '/api/v1/channels/text-1/attachments',
      expect.objectContaining({ method: 'POST', credentials: 'same-origin' }),
    )
    const form = request.mock.calls[0]?.[1]?.body as FormData
    expect(form.get('file')).toMatchObject({ name: 'notes.txt', size: 4 })
  })

  it('rejects malformed private upload metadata', async () => {
    const file = new File(['note'], 'notes.txt', { type: 'text/plain' })
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      id: 'attachment-1', original_name: 'notes.txt', byte_size: '4',
    }), { status: 201 }))

    await expect(uploadTextAttachment('text-1', file, request)).rejects.toThrow('некорректные данные')
  })
})
