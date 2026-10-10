const offlineMessage = 'Нет соединения с сервером. Проверьте подключение.'
const timeoutMessage = 'Сервер не ответил вовремя. Повторите попытку.'

export interface RequestFailureFeedback { message: string; retryable: boolean }

export function requestFailureFeedback(cause: unknown, fallback: string): RequestFailureFeedback {
  if (typeof cause === 'object' && cause !== null && 'status' in cause && typeof cause.status === 'number') {
    const status = cause.status
    if (status === 401) return { message: 'Сессия завершена. Войдите снова.', retryable: false }
    if (status === 403) return { message: 'Нет доступа к этому действию.', retryable: false }
    if (status === 404) return { message: 'Запрошенный ресурс не найден.', retryable: false }
    if (status === 409) return { message: 'Данные изменились. Обновите их перед повтором.', retryable: true }
    if (status === 429) return { message: 'Слишком много запросов. Подождите немного и повторите попытку.', retryable: true }
    if (status === 408 || status >= 500) return { message: 'Сервис временно не отвечает. Попробуйте позже.', retryable: true }
  }
  if (cause instanceof Error) {
    const name = cause.name.toLowerCase()
    const message = cause.message.trim()
    if (name === 'timeouterror' || /\b(timeout|timed out)\b/i.test(message)) return { message: timeoutMessage, retryable: true }
    if (name === 'aborterror') return { message: fallback, retryable: false }
    if (/failed to fetch|networkerror|network request failed|offline|econnrefused/i.test(message)) return { message: offlineMessage, retryable: true }
    if (message) return { message, retryable: true }
  }
  return { message: fallback, retryable: true }
}

export function requestFailureMessage(cause: unknown, fallback: string): string {
  return requestFailureFeedback(cause, fallback).message
}
