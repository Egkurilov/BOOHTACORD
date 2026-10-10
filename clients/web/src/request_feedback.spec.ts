import { describe, expect, it } from 'vitest'

import { requestFailureFeedback, requestFailureMessage } from './request_feedback'

describe('request failure presentation', () => {
  it('localizes offline and timeout failures', () => {
    expect(requestFailureMessage(new TypeError('Failed to fetch'), 'fallback')).toBe('Нет соединения с сервером. Проверьте подключение.')
    expect(requestFailureMessage(new Error('offline'), 'fallback')).toBe('Нет соединения с сервером. Проверьте подключение.')
    expect(requestFailureMessage(Object.assign(new Error('request'), { name: 'TimeoutError' }), 'fallback')).toBe('Сервер не ответил вовремя. Повторите попытку.')
  })

  it('preserves a meaningful server message and uses fallback for cancellation', () => {
    expect(requestFailureMessage(new Error('Недостаточно прав.'), 'fallback')).toBe('Недостаточно прав.')
    expect(requestFailureMessage(Object.assign(new Error('cancelled'), { name: 'AbortError' }), 'fallback')).toBe('fallback')
  })

  it('does not offer a blind retry after access denial and keeps transient errors retryable', () => {
    expect(requestFailureFeedback(Object.assign(new Error('403'), { status: 403 }), 'fallback')).toEqual({ message: 'Нет доступа к этому действию.', retryable: false })
    expect(requestFailureFeedback(Object.assign(new Error('503'), { status: 503 }), 'fallback').retryable).toBe(true)
    expect(requestFailureFeedback(new TypeError('Failed to fetch'), 'fallback').retryable).toBe(true)
  })
})
