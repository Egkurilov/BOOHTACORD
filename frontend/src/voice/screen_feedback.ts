import type { ScreenDiagnostics } from './screen_diagnostics'

export function screenFailureMessage(cause: unknown): string {
  const name = cause instanceof Error ? cause.name : ''
  if (name === 'AbortError') return 'Выбор источника отменён. Откройте демонстрацию снова и выберите окно, экран или вкладку.'
  if (name === 'NotAllowedError') return 'Браузер запретил захват экрана. Разрешите его в Chrome и повторите выбор источника.'
  if (name === 'NotReadableError') return 'Источник недоступен для захвата. Закройте конфликтующее приложение или выберите другой источник.'
  return 'Демонстрация не начата: браузер или сеть не вернули техническую причину. Повторите действие или выберите другой источник.'
}

export function screenDiagnosticMessage(diagnostics: ScreenDiagnostics): string | null {
  if (diagnostics.source === 'ENDED') return 'Источник демонстрации завершён. Выберите его снова, чтобы продолжить показ.'
  if (diagnostics.audioTrack === 'ABSENT') return 'Демонстрация идёт без аудиодорожки. Выберите источник, для которого Chrome предлагает передавать звук.'
  if (diagnostics.adaptationReason === 'bandwidth' || diagnostics.connectionQuality === 'POOR' || diagnostics.connectionQuality === 'LOST') {
    return 'Сеть ограничивает демонстрацию. Голос имеет приоритет; проверьте соединение и обновите измерения.'
  }
  return null
}
