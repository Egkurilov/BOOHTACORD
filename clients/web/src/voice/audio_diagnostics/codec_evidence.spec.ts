import { expect, it } from 'vitest'
import { audioCodec } from './codec'
it('does not claim RED disabled from an Opus codec stats record', () => {
  const codec = audioCodec({ codecId: 'opus' }, [
    { id: 'opus', type: 'codec', mimeType: 'audio/opus', clockRate: 48000, channels: 2 },
  ])
  expect(codec.codec).toBe('opus')
  expect(codec.red).toBeNull()
})
