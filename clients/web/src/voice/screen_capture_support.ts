export function screenCaptureSupported(
  userAgent: string = typeof navigator === 'undefined' ? '' : navigator.userAgent,
  mediaDevices: { getDisplayMedia?: unknown } | undefined = typeof navigator === 'undefined' ? undefined : navigator.mediaDevices,
): boolean {
  if (/Android/i.test(userAgent) && /Chrome\//i.test(userAgent)) return false
  return typeof mediaDevices?.getDisplayMedia === 'function'
}

export function screenCaptureUnavailableMessage(
  userAgent: string = typeof navigator === 'undefined' ? '' : navigator.userAgent,
): string {
  if (/Android/i.test(userAgent)) return 'Показ экрана в браузере Android недоступен. Запустите трансляцию в Android-приложении или в браузере на ПК.'
  return 'Этот браузер не поддерживает показ экрана. Используйте браузер на ПК с доступным захватом экрана.'
}
