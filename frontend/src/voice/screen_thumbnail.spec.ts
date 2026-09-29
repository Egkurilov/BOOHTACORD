import { describe, expect, it } from 'vitest'

import { screenThumbnailTopic, validScreenThumbnail } from './screen_thumbnail'

describe('screen thumbnail packets', () => {
  it('accepts a bounded JPEG on the dedicated LiveKit data topic', () => {
    expect(screenThumbnailTopic).toBe('boohtacord.screen.thumbnail.v1')
    expect(validScreenThumbnail(new Uint8Array([0xff, 0xd8, 0xff, 0xd9]))).toBe(true)
    expect(validScreenThumbnail(new Uint8Array(33 * 1024))).toBe(false)
    expect(validScreenThumbnail(new Uint8Array([1, 2, 3]))).toBe(false)
  })
})
