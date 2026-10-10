const fallbackMessage = 'Не удалось подключиться к голосовому каналу.'

export function voiceJoinErrorMessage(cause: unknown): string {
  if (!(cause instanceof Error)) return fallbackMessage

  if (cause.name === 'NotFoundError') {
    return 'Микрофон не найден. Подключитесь без микрофона или подключите устройство и повторите попытку.'
  }
  if (cause.name === 'OverconstrainedError') {
    return 'Выбранный микрофон не поддерживает необходимые настройки. Выберите другое устройство или подключитесь без микрофона.'
  }

  return cause.message || fallbackMessage
}
