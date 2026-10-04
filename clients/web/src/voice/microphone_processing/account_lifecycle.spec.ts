import { expect, it, vi } from 'vitest'
import { createAudioProcessingControls } from '../audio_processing_controls'
import { bindMicrophoneAccount, microphoneSettings } from './runtime'
it('does not apply a delayed previous-account load after logout', async () => {
  let resolve!: (value: { accountId: string }) => void
  const account = new Promise<{ accountId: string }>(done => { resolve = done })
  bindMicrophoneAccount('old')
  const processing = createAudioProcessingControls(() => account)
  const apply = vi.fn(async () => {})
  const pending = processing.start(apply)
  bindMicrophoneAccount(null)
  resolve({ accountId: 'old' })
  await pending
  expect(apply).not.toHaveBeenCalled()
  expect(microphoneSettings.value).toEqual({ vadThresholdDb: -50, microphoneGainPercent: 100 })
})
