import { expect, test } from '@playwright/test'
import { decodeFrameMarker, encodeFrameMarker } from './frame_marker'

test('numbered synthetic frames survive marker encoding and decoding', () => {
  for (const frame of [0, 1, 42, 2048, 65535]) {
    const luma = encodeFrameMarker(frame).map(bit => bit ? 255 : 0)
    expect(decodeFrameMarker(luma)).toBe(frame & 0xfff)
  }
  expect(decodeFrameMarker([0, 255, 0])).toBeNull()
})
