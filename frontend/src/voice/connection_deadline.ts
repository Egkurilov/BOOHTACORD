export const mediaConnectionTimeoutMs = 20_000

export function awaitMediaConnection<T>(action: Promise<T>, timeoutMs = mediaConnectionTimeoutMs): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('Превышено время ожидания голосового подключения.')), timeoutMs)
    void action.then(resolve, reject).finally(() => clearTimeout(timeout))
  })
}
