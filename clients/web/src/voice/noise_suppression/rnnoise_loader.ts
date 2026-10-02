const VERSION = 'v0.1-cdf196b'
const SOURCE = 'cdf196b1e9de2f8ff1003328ebf9a4316477429d'
const ARCHIVE = 'a6f3bd89c5c12546d049bcdcf6d1b58c301fd9c811e760f3087b036a93501d98'
const MODEL = 'f0cdb52b30501aab489f90fedbc7a023c719d91b337db2da7f26fc3036556b95'
export const RNNOISE_MANIFEST_PATH = `/audio/rnnoise/${VERSION}/rnnoise-manifest.json`
export interface RnnoiseAssets { module: WebAssembly.Module; modelId: string; wasmSha256: string }
const loading = new Map<string, Promise<RnnoiseAssets>>()
export async function loadRnnoiseAssets(manifestPath = RNNOISE_MANIFEST_PATH, timeoutMs = 8000): Promise<RnnoiseAssets> {
  const url = new URL(manifestPath, window.location.origin)
  if (url.origin !== window.location.origin) throw new Error('RNNoise assets must be same origin')
  const key = url.href
  let pending = loading.get(key)
  if (!pending) {
    pending = load(url, timeoutMs)
    loading.set(key, pending)
    void pending.catch(() => { if (loading.get(key) === pending) loading.delete(key) })
  }
  return pending
}
async function load(url: URL, timeoutMs: number): Promise<RnnoiseAssets> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeoutMs)
  try {
    const response = await fetch(url, { credentials: 'same-origin', signal: controller.signal, redirect: 'error' })
    if (!response.ok || !response.headers.get('content-type')?.includes('application/json')) throw new Error('RNNoise manifest unavailable')
    const info = await response.json()
    if (info.version !== VERSION || info.sourceCommit !== SOURCE || info.sourceArchiveSha256 !== ARCHIVE || info.modelSha256 !== MODEL ||
        info.modelId !== 'rnnoise-stock-v0.1' || info.frameSize !== 480 || info.sampleRate !== 48000 ||
        info.pcmScale !== 32768 || info.threads !== 1 || info.simd !== false || info.wasmFile !== 'rnnoise.wasm' ||
        !/^[a-f0-9]{64}$/.test(info.wasmSha256)) throw new Error('RNNoise manifest incompatible')
    const wasmResponse = await fetch(new URL(info.wasmFile, url), { credentials: 'same-origin', signal: controller.signal, redirect: 'error' })
    if (!wasmResponse.ok || !wasmResponse.headers.get('content-type')?.includes('application/wasm')) throw new Error('RNNoise WASM unavailable')
    const bytes = await wasmResponse.arrayBuffer()
    const checksum = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)), byte => byte.toString(16).padStart(2, '0')).join('')
    if (checksum !== info.wasmSha256) throw new Error('RNNoise WASM checksum mismatch')
    const module = await WebAssembly.compile(bytes)
    if (WebAssembly.Module.imports(module).length !== 0) throw new Error('RNNoise WASM requires unexpected imports')
    return { module, modelId: info.modelId, wasmSha256: checksum }
  } finally { clearTimeout(timer) }
}
