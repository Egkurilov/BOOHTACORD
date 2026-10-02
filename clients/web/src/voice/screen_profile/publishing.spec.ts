import { expect, it, vi } from 'vitest'
import { startScreenShare, stopScreenShare } from '../media_publishing'
import type { VoiceRoom } from '../livekit_gateway'

it('configures the actual sender before returning first diagnostics', async () => {
  const calls: string[] = []
  const room = { localParticipant: {
    setScreenShareEnabled: vi.fn(async () => { calls.push('publish') }),
    updateScreenShareProfile: vi.fn(async () => { calls.push('apply') }),
  }, readScreenDiagnostics: vi.fn(async () => { calls.push('read'); return {} }) } as unknown as VoiceRoom
  await startScreenShare(room, 'P1080_60')
  expect(calls).toEqual(['publish', 'apply', 'read'])
})

it('unpublishes an initial share if the selected profile cannot be applied', async () => {
  const room = { localParticipant: { setScreenShareEnabled: vi.fn().mockResolvedValue(undefined),
    updateScreenShareProfile: vi.fn().mockRejectedValue(new Error('rejected')) } } as unknown as VoiceRoom
  await expect(startScreenShare(room, 'P1080_60')).rejects.toThrow('rejected')
  expect(room.localParticipant.setScreenShareEnabled).toHaveBeenLastCalledWith(false)
})

it('invalidates profile checks before awaiting unpublication', async () => {
  const calls: string[] = []
  const room = { stopScreenProfileChecks: () => calls.push('stop'), localParticipant: {
    setScreenShareEnabled: async () => { calls.push('unpublish') },
  } } as unknown as VoiceRoom
  await stopScreenShare(room)
  expect(calls).toEqual(['stop', 'unpublish'])
})
