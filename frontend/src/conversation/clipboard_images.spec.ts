import { readFileSync } from 'node:fs'
import { describe, expect, it, vi } from 'vitest'

import { pasteClipboardImages } from './clipboard_images'

function pasteEvent({
  files = [],
  text = '',
}: { files?: File[]; text?: string } = {}): Pick<ClipboardEvent, 'clipboardData' | 'preventDefault'> {
  const items = files.map((file) => ({
    kind: 'file',
    type: file.type,
    getAsFile: () => file,
  })) as unknown as DataTransferItemList
  const clipboardData = {
    items,
    files: files as unknown as FileList,
    getData: (type: string) => type === 'text/plain' ? text : '',
  } as DataTransfer
  return { clipboardData, preventDefault: vi.fn() }
}

describe('clipboard image paste', () => {
  it('uploads pasted images without altering ordinary text paste', () => {
    const event = pasteEvent({ files: [new File(['image'], 'capture.png', { type: 'image/png' })] })
    const input = { selectionStart: 2, selectionEnd: 4, setRangeText: vi.fn(), dispatchEvent: vi.fn() }
    const addFiles = vi.fn()

    expect(pasteClipboardImages(event, input, addFiles)).toBe(true)
    expect(event.preventDefault).toHaveBeenCalledOnce()
    expect(addFiles.mock.calls[0]?.[0]).toMatchObject([{ name: 'capture.png', type: 'image/png' }])

    const textEvent = pasteEvent({ text: 'обычный текст' })
    expect(pasteClipboardImages(textEvent, input, addFiles)).toBe(false)
    expect(textEvent.preventDefault).not.toHaveBeenCalled()
    expect(addFiles).toHaveBeenCalledOnce()
  })

  it('preserves accompanying text at the selection and gives anonymous blobs a filename', () => {
    const event = pasteEvent({
      files: [new File(['image'], '', { type: 'image/jpeg' })],
      text: 'подпись',
    })
    const input = { selectionStart: 1, selectionEnd: 3, setRangeText: vi.fn(), dispatchEvent: vi.fn() }
    const addFiles = vi.fn()

    expect(pasteClipboardImages(event, input, addFiles)).toBe(true)
    expect(input.setRangeText).toHaveBeenCalledWith('подпись', 1, 3, 'end')
    expect(input.dispatchEvent).toHaveBeenCalledOnce()
    expect(addFiles.mock.calls[0]?.[0]).toMatchObject([{ name: 'clipboard-image-1.jpg' }])
  })

  it('ignores non-image files and plain clipboard text', () => {
    const event = pasteEvent({ files: [new File(['text'], 'note.txt', { type: 'text/plain' })], text: 'note' })
    const input = { selectionStart: 0, selectionEnd: 0, setRangeText: vi.fn(), dispatchEvent: vi.fn() }
    const addFiles = vi.fn()

    expect(pasteClipboardImages(event, input, addFiles)).toBe(false)
    expect(event.preventDefault).not.toHaveBeenCalled()
    expect(input.setRangeText).not.toHaveBeenCalled()
    expect(addFiles).not.toHaveBeenCalled()
  })

  it.each([
    ['TEXT', '../conversation/TextConversation.vue', './TextMessageAttachmentPicker.vue'],
    ['DM', '../direct_message/DirectMessageConversation.vue', '../direct_message/DirectMessageAttachmentPicker.vue'],
  ])('wires the %s composer paste event into its scoped attachment queue', (_kind, conversationPath, pickerPath) => {
    const conversation = readFileSync(new URL(conversationPath, import.meta.url), 'utf8')
    const picker = readFileSync(new URL(pickerPath, import.meta.url), 'utf8')

    expect(conversation).toContain('@paste="onComposerPaste"')
    expect(conversation).toContain('pasteClipboardImages(event, composerTextarea.value')
    expect(conversation).toContain('attachmentPicker.value?.addPastedFiles(files)')
    expect(picker).toContain('defineExpose({ addPastedFiles })')
    expect(picker).toContain('function addPastedFiles(files: File[]): void')
  })

  it('keeps the DM paste upload bound to its captured conversation and offers retry', () => {
    const picker = readFileSync(new URL('../direct_message/DirectMessageAttachmentPicker.vue', import.meta.url), 'utf8')
    expect(picker).toContain('const target = props.directMessageId')
    expect(picker).toContain('target !== props.directMessageId')
    expect(picker).toContain('failed.value = [...failed.value, file]')
    expect(picker).toContain('const files = failed.value')
    expect(picker).toContain('void upload(files)')
  })
})
