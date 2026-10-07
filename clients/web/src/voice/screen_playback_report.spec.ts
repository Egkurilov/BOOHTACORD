import { afterEach, expect, it, vi } from 'vitest'
import { createRenderer, nextTick, ref } from 'vue'
import { useScreenPlaybackQuality } from './screen_playback_quality'
import { buildScreenClientReport, startScreenClientReporting } from './screen_client_reporter'
const request = vi.hoisted(() => vi.fn(async () => new Response(null, { status: 204 })))
vi.mock('../telemetry/client_tracing', () => ({ tracedFetch: request }))
vi.mock('../telemetry/media_sample/record', () => ({ recordMediaSample: vi.fn() }))
vi.mock('../telemetry/journey_intervals/runtime', () => ({ markScreenFrame: vi.fn() }))
const renderer = createRenderer<any, any>({ createComment: () => ({}), createElement: () => ({}), createText: () => ({}),
  insert: () => {}, nextSibling: () => null, parentNode: () => null, patchProp: () => {}, remove: () => {}, setElementText: () => {}, setText: () => {} })
afterEach(() => { vi.useRealTimers(); vi.unstubAllGlobals(); request.mockClear() })
it('exports first actual rVFC time through mounted Vue hooks and authenticated report API', async () => {
  vi.useFakeTimers()
  let callback: VideoFrameRequestCallback | undefined
  const element = { videoWidth: 1920, videoHeight: 1080, requestVideoFrameCallback: (next: VideoFrameRequestCallback) => { callback = next; return 1 }, cancelVideoFrameCallback: vi.fn() } as unknown as HTMLVideoElement
  const video = ref<HTMLVideoElement | null>(null)
  let observed: ReturnType<typeof useScreenPlaybackQuality> | undefined
  const app = renderer.createApp({ setup() { observed = useScreenPlaybackQuality(video, () => 'screen', () => false); return () => null } })
  app.mount({})
  video.value = element
  await nextTick()
  const stop = startScreenClientReporting(() => buildScreenClientReport({ platform: 'desktop_web', selected: true, hasTrack: true,
    videoReady: observed!.videoReady.value, playbackFps: observed!.playbackFps.value, receiverMetrics: null,
    firstFrameMs: observed!.firstFrameMs.value, presentationSource: observed!.presentationSource.value }), () => true)
  await vi.advanceTimersByTimeAsync(300)
  callback?.(300, { presentedFrames: 1 } as VideoFrameCallbackMetadata)
  await vi.advanceTimersByTimeAsync(4700)
  expect(request).toHaveBeenCalledOnce()
  const payload = JSON.parse((request.mock.calls[0] as unknown as [string, RequestInit])[1].body as string)
  expect(payload).toMatchObject({ first_frame_ms: 300, presentation_source: 'web_rvfc', direction: 'receiver' })
  expect(JSON.stringify(payload)).not.toContain('screen')
  stop(); app.unmount()
  await vi.advanceTimersByTimeAsync(5000)
  expect(request).toHaveBeenCalledOnce()
})
