export function resolvePublicOrigin(value: string | undefined, mode: string): string {
  const input = value?.trim()
  if (!input) {
    if (mode === 'production') throw new Error('VITE_PUBLIC_ORIGIN is required for production builds')
    return ''
  }
  let url: URL
  try { url = new URL(input) } catch { throw new Error('VITE_PUBLIC_ORIGIN must be an absolute origin') }
  const localHost = ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname.toLowerCase())
  const secure = url.protocol === 'https:' || (url.protocol === 'http:' && localHost)
  if (!secure || !url.hostname || url.username || url.password || url.port === '0' || url.pathname !== '/' || url.search || url.hash) {
    throw new Error('VITE_PUBLIC_ORIGIN must be HTTPS, except for a loopback development origin')
  }
  return url.origin
}
