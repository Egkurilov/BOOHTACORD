export type DeliveryStatus = 'sending' | 'checking' | 'failed'
interface Delivery<T> { post(): Promise<T>; lookup(): Promise<T | null>; status(value: DeliveryStatus): void; active(): boolean; timeoutMs?: number }
export function uncertainFailure(cause: unknown): boolean {
  const status = typeof cause === 'object' && cause !== null && 'status' in cause ? cause.status : undefined
  return typeof status !== 'number' || status >= 500 && status !== 507 || status === 408
}
export async function deliverWithRecovery<T>(port: Delivery<T>, retry: boolean): Promise<T> {
  async function bounded<R>(operation: Promise<R>): Promise<R> {
    let timer: ReturnType<typeof setTimeout> | undefined
    try { return await Promise.race([operation, new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new Error('Ответ сервера не получен. Проверьте доставку.')), port.timeoutMs ?? 20000) })]) }
    finally { if (timer !== undefined) clearTimeout(timer) }
  }
  const active = () => { if (!port.active()) throw new Error('Сеанс изменился. Отправка остановлена.') }
  async function check(): Promise<T | null> { active(); port.status('checking'); const found = await bounded(port.lookup()); active(); return found }
  if (retry) { const found = await check(); if (found) return found }
  active(); port.status('sending')
  try { const sent = await bounded(port.post()); active(); return sent }
  catch (cause) {
    active()
    if (uncertainFailure(cause)) { const found = await check(); if (found) return found }
    throw cause
  }
}
