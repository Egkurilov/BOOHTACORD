import { describe, expect, it, vi } from 'vitest'

import { ScreenViewerController, type ScreenViewerStream } from './screen_viewer_controller'

describe('screen viewer receiver stats', () => {
  it('exposes LiveKit receiver stats only for the remote track', async () => {
    const read = vi.fn().mockResolvedValue({ timestamp: 1, framesDecoded: 2, framesDropped: 0 })
    const remote: ScreenViewerStream = {
      hasAudio: false, id: 'remote', participantId: 'remote', participantName: 'Alice',
      video: { track: { attach: vi.fn(), detach: vi.fn(), getReceiverStats: read } },
    }
    const local: ScreenViewerStream = { ...remote, id: 'local', isLocal: true }
    const controller = new ScreenViewerController(() => [remote, local])

    expect(controller.cards()[0]?.readReceiverStats).toBeDefined()
    await controller.cards()[0]?.readReceiverStats?.()
    expect(read).toHaveBeenCalledOnce()
    expect(controller.cards()[1]?.readReceiverStats).toBeUndefined()
  })
})
