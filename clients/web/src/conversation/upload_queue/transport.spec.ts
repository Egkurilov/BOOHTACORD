import { afterEach, expect, it, vi } from 'vitest'
import { progressRequest } from './transport'

class XHR {
  static current: XHR
  status = 201; statusText = 'Created'; responseText = '{"id":"safe"}'; withCredentials = false
  upload = { onprogress: null as ((event: { loaded: number; total: number; lengthComputable: boolean }) => void) | null }
  onload: (() => void) | null = null; onabort: (() => void) | null = null; onerror: (() => void) | null = null
  open = vi.fn(); send = vi.fn(); setRequestHeader = vi.fn()
  abort = vi.fn(() => this.onabort?.())
  getAllResponseHeaders = () => 'content-type: application/json\r\n'
  constructor() { XHR.current = this }
}
afterEach(() => vi.unstubAllGlobals())

it('uses the native multipart body and reports upload progress before the server acknowledgement', async () => {
  vi.stubGlobal('XMLHttpRequest', XHR)
  const controller = new AbortController(), progress = vi.fn(), body = new FormData()
  const response = progressRequest({ signal: controller.signal, onProgress: progress })('/api/v1/channels/safe/attachments', {
    method: 'POST', credentials: 'same-origin', headers: { accept: 'application/json' }, body,
  })
  expect(XHR.current.send).toHaveBeenCalledWith(body)
  expect(XHR.current.setRequestHeader).not.toHaveBeenCalledWith('content-type', expect.anything())
  XHR.current.upload.onprogress?.({ loaded: 5, total: 10, lengthComputable: true })
  expect(progress).toHaveBeenCalledWith(50)
  XHR.current.onload?.()
  expect((await response).status).toBe(201)
  controller.abort()
  expect(XHR.current.abort).not.toHaveBeenCalled()
})

it('aborts the actual in-flight XHR and rejects rather than preparing an attachment ID', async () => {
  vi.stubGlobal('XMLHttpRequest', XHR)
  const controller = new AbortController()
  const response = progressRequest({ signal: controller.signal, onProgress: vi.fn() })('/api/v1/channels/safe/attachments')
  controller.abort()
  await expect(response).rejects.toMatchObject({ name: 'AbortError' })
  expect(XHR.current.abort).toHaveBeenCalledOnce()
})

it('does not transmit a request whose scope was already canceled', async () => {
  vi.stubGlobal('XMLHttpRequest', XHR)
  const controller = new AbortController(); controller.abort()
  await expect(progressRequest({ signal: controller.signal, onProgress: vi.fn() })('/api/v1/channels/safe/attachments')).rejects.toMatchObject({ name: 'AbortError' })
  expect(XHR.current.send).not.toHaveBeenCalled()
})
