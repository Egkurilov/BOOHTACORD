import { trace } from '@opentelemetry/api'
import { createTracedFetch } from '../../telemetry/client_tracing'
import type { UploadControl } from './types'

export function progressRequest(control: UploadControl): typeof fetch {
  const transport: typeof fetch = (input, init) => new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest(), signal = init?.signal ?? control.signal
    let settled = false
    const finish = (response?: Response, error?: Error) => {
      if (settled) return
      settled = true; signal?.removeEventListener('abort', abort)
      if (response) resolve(response); else reject(error)
    }
    const abort = () => { xhr.abort(); finish(undefined, new DOMException('Загрузка отменена.', 'AbortError')) }
    xhr.open(init?.method ?? 'POST', String(input))
    xhr.withCredentials = init?.credentials === 'include'
    new Headers(init?.headers).forEach((value, key) => xhr.setRequestHeader(key, value))
    xhr.upload.onprogress = event => { if (event.lengthComputable) control.onProgress(event.loaded / event.total * 100) }
    xhr.onerror = () => finish(undefined, new Error('Не удалось загрузить вложение. Проверьте соединение.'))
    xhr.onabort = () => finish(undefined, new DOMException('Загрузка отменена.', 'AbortError'))
    xhr.onload = () => {
      const headers = new Headers()
      for (const line of xhr.getAllResponseHeaders().trim().split(/[\r\n]+/)) {
        const at = line.indexOf(':'); if (at > 0) headers.append(line.slice(0, at), line.slice(at + 1).trim())
      }
      finish(new Response(xhr.responseText, { status: xhr.status, statusText: xhr.statusText, headers }))
    }
    signal?.addEventListener('abort', abort, { once: true })
    if (signal?.aborted) abort(); else xhr.send(init?.body as FormData)
  })
  return createTracedFetch(trace.getTracer('boohtacord/web'), transport)
}
