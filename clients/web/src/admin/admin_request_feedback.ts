export class AdminResponseError extends Error {
  constructor(readonly status: number) {
    super(`Admin request failed with status ${status}`)
    this.name = 'AdminResponseError'
  }
}

export interface AdminRequestFeedback {
  message: string
  retryable: boolean
}

export function adminRequestFeedback(error: unknown): AdminRequestFeedback {
  if (error instanceof AdminResponseError) {
    if (error.status === 401) return { message: 'Сессия завершена. Войдите снова.', retryable: false }
    if (error.status === 403) return { message: 'Нет доступа к этому разделу.', retryable: false }
    if (error.status === 404) return { message: 'Запрошенный ресурс не найден.', retryable: false }
    if (error.status === 409) return { message: 'Данные изменились. Обновите экран и повторите попытку.', retryable: true }
    if (error.status === 429) return { message: 'Слишком много запросов. Подождите немного и повторите попытку.', retryable: true }
    if (error.status >= 500 && error.status < 600) return { message: 'Сервис временно не отвечает. Попробуйте позже.', retryable: true }
    return { message: 'Не удалось загрузить данные. Повторите попытку.', retryable: error.status >= 500 || error.status === 408 }
  }

  if (error instanceof TypeError) return { message: 'Нет соединения с сервером. Проверьте подключение.', retryable: true }
  if (error instanceof Error && error.message.trim()) return { message: error.message, retryable: true }
  return { message: 'Не удалось загрузить данные. Повторите попытку.', retryable: true }
}
