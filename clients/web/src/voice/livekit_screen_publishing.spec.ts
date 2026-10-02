import { describe, expect, it, vi } from 'vitest'

import {
  adaptiveMediaRoomOptions,
  startScreenShare,
  stopScreenShare,
  type VoiceRoom,
} from './livekit_gateway'

function screenRoom(readScreenDiagnostics?: VoiceRoom['readScreenDiagnostics']): VoiceRoom {
  return {
    readScreenDiagnostics,
    localParticipant: {
      setMicrophoneEnabled: vi.fn(),
      setScreenShareEnabled: vi.fn().mockResolvedValue(undefined),
    },
  } as unknown as VoiceRoom
}

describe('LiveKit screen publishing policy', () => {
  it.each([
    ['P720_15', 1280, 720, 15, 1_500_000],
    ['P720_30', 1280, 720, 30, 2_500_000],
    ['P720_60', 1280, 720, 60, 4_000_000],
    ['P1080_15', 1920, 1080, 15, 2_500_000],
    ['P1080_30', 1920, 1080, 30, 5_000_000],
    ['P1080_60', 1920, 1080, 60, 8_000_000],
    ['P1440_15', 2560, 1440, 15, 5_000_000],
    ['P1440_30', 2560, 1440, 30, 8_000_000],
    ['P1440_60', 2560, 1440, 60, 12_000_000],
  ] as const)('starts capture and encoding with the selected %s profile', async (profile, width, height, frameRate, maxBitrate) => {
    const fakeRoom = screenRoom()
    await startScreenShare(fakeRoom, profile)
    expect(fakeRoom.localParticipant.setScreenShareEnabled).toHaveBeenCalledWith(true, {
      audio: true, resolution: { width, height, frameRate },
    }, { name: `screenshare-${height}p-${frameRate}fps`, degradationPreference: 'maintain-framerate', screenShareEncoding: { maxBitrate, maxFramerate: frameRate, priority: 'medium' } })
  })

  it('passes the selected capture size and degradation preference as publish options', async () => {
    const fakeRoom = screenRoom()

    await startScreenShare(fakeRoom, 'P1080_60')
    await stopScreenShare(fakeRoom)

    expect(fakeRoom.localParticipant.setScreenShareEnabled).toHaveBeenNthCalledWith(1, true, {
      audio: true, resolution: { width: 1920, height: 1080, frameRate: 60 },
    }, { name: 'screenshare-1080p-60fps', degradationPreference: 'maintain-framerate', screenShareEncoding: { maxBitrate: 8_000_000, maxFramerate: 60, priority: 'medium' } })
    expect(fakeRoom.localParticipant.setScreenShareEnabled).toHaveBeenNthCalledWith(2, false)
  })

  it('returns only observed screen diagnostics after publishing', async () => {
    const diagnostics = {
      audioTrack: 'ABSENT' as const,
      connectionQuality: 'GOOD' as const,
      measured: { framesPerSecond: 30, height: 720, width: 1280 },
      source: 'ACTIVE' as const,
    }
    const fakeRoom = screenRoom(vi.fn().mockResolvedValue(diagnostics))

    await expect(startScreenShare(fakeRoom, 'P1080_60')).resolves.toEqual(diagnostics)
    expect(fakeRoom.localParticipant.setScreenShareEnabled).toHaveBeenCalledWith(true, {
      audio: true, resolution: { width: 1920, height: 1080, frameRate: 60 },
    }, { name: 'screenshare-1080p-60fps', degradationPreference: 'maintain-framerate', screenShareEncoding: { maxBitrate: 8_000_000, maxFramerate: 60, priority: 'medium' } })
  })

  it('declares adaptive receive quality and dynacast room preferences', () => {
    expect(adaptiveMediaRoomOptions).toEqual({ adaptiveStream: true, dynacast: true })
  })
})
