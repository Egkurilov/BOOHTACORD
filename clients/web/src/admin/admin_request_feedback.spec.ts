import { describe, expect, it } from 'vitest'
import { AdminResponseError, adminRequestFeedback } from './admin_request_feedback'

describe('admin request feedback', () => {
  it.each([401, 403, 404])('explains HTTP %s without offering a blind retry', (status) => {
    const result = adminRequestFeedback(new AdminResponseError(status))

    expect(result).toEqual({ message: status === 404 ? 'Запрошенный ресурс не найден.' : status === 401 ? 'Сессия завершена. Войдите снова.' : 'Нет доступа к этому разделу.', retryable: false })
  })

  it.each([409, 429, 500, 503])('keeps HTTP %s recoverable with a useful next step', (status) => {
    const result = adminRequestFeedback(new AdminResponseError(status))

    expect(result.retryable).toBe(true)
    if (status === 409) expect(result.message).toBe('Данные изменились. Обновите экран и повторите попытку.')
    if (status === 429) expect(result.message).toBe('Слишком много запросов. Подождите немного и повторите попытку.')
    if (status >= 500) expect(result.message).toBe('Сервис временно не отвечает. Попробуйте позже.')
  })

  it('separates network failures from malformed domain responses', () => {
    expect(adminRequestFeedback(new TypeError('fetch failed'))).toEqual({
      message: 'Нет соединения с сервером. Проверьте подключение.',
      retryable: true,
    })
    expect(adminRequestFeedback(new Error('Некорректные показатели медиа.'))).toEqual({
      message: 'Некорректные показатели медиа.',
      retryable: true,
    })
  })
})
