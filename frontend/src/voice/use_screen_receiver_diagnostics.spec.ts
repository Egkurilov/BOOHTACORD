import { afterEach, describe, expect, it, vi } from 'vitest'
import { createRenderer, nextTick, ref } from 'vue'

import type { ScreenViewerCard } from './screen_viewer_types'
import { useScreenReceiverDiagnostics } from './use_screen_receiver_diagnostics'

const renderer = createRenderer<any, any>({
  createComment: () => ({}), createElement: () => ({}), createText: () => ({}),
  insert: () => {}, nextSibling: () => null, parentNode: () => null,
  patchProp: () => {}, remove: () => {}, setElementText: () => {}, setText: () => {},
})

afterEach(() => vi.useRealTimers())

describe('receiver sampling lifecycle', () => {
  it('measures consecutive receiver samples and resets when the viewed screen changes', async () => {
    vi.useFakeTimers()
    const first = vi.fn()
      .mockResolvedValueOnce({ timestamp: 1000, framesDecoded: 20, framesDropped: 0, bytesReceived: 1000 })
      .mockResolvedValueOnce({ timestamp: 3000, framesDecoded: 140, framesDropped: 1, bytesReceived: 1_001_000 })
    const selected = ref<ScreenViewerCard | null>({ id: 'first', hasAudio: false, participantId: 'a', participantName: 'A', readReceiverStats: first })
    let observed: ReturnType<typeof useScreenReceiverDiagnostics> | undefined
    const app = renderer.createApp({ setup() { observed = useScreenReceiverDiagnostics(selected, () => false); return () => null } })
    app.mount({})
    await Promise.resolve()
    expect(observed?.metrics.value?.decodedFps).toBeNull()

    await vi.advanceTimersByTimeAsync(2000)
    expect(observed?.metrics.value?.decodedFps).toBe(60)
    expect(observed?.metrics.value?.bitrateKbps).toBe(4000)

    const second = vi.fn().mockResolvedValue({ timestamp: 5000, framesDecoded: 10, framesDropped: 0 })
    selected.value = { ...selected.value!, id: 'second', readReceiverStats: second }
    await nextTick()
    await Promise.resolve()
    expect(observed?.metrics.value?.decodedFps).toBeNull()
    expect(second).toHaveBeenCalledOnce()

    app.unmount()
    await vi.advanceTimersByTimeAsync(4000)
    expect(second).toHaveBeenCalledOnce()
  })
})
