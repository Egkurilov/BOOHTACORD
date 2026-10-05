export function retryAfterSeconds(value: string | null, now = Date.now()): number | null {
  if (value === null || !value.trim()) return null
  if (/^\d+$/.test(value.trim())) {
    const seconds = Number(value)
    return Number.isSafeInteger(seconds) ? seconds : null
  }
  if (!/^[A-Za-z]{3}, \d{2} [A-Za-z]{3} \d{4} \d{2}:\d{2}:\d{2} GMT$/.test(value)) return null
  const time = Date.parse(value)
  return Number.isFinite(time) ? Math.max(0, Math.ceil((time-now)/1000)) : null
}

export class AuthenticationRateLimitError extends Error {
  constructor(readonly retryAfter: number | null) {
    super(retryAfter === null ? 'Слишком много попыток. Подождите и повторите вручную.'
      : `Слишком много попыток. Повторите вручную через ${retryAfter} с.`)
  }
}

export function rateLimitError(response: Response): AuthenticationRateLimitError {
  const date = Date.parse(response.headers.get('date') ?? '')
  return new AuthenticationRateLimitError(retryAfterSeconds(response.headers.get('retry-after'),
    Number.isFinite(date) ? date : Date.now()))
}
