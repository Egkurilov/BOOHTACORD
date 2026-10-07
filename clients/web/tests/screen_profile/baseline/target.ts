export function isSafeLiveKitUrl(value: string) {
  try {
    const url = new URL(value)
    return url.protocol === 'wss:' || (url.protocol === 'ws:' && ['localhost', '127.0.0.1', '::1', '[::1]'].includes(url.hostname))
  } catch {
    return false
  }
}
