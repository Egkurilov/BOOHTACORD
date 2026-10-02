import { describe, expect, it } from 'vitest'

import { validScreenThumbnail } from './screen_thumbnail'

describe('screen thumbnail frames', () => {
  it('accepts only bounded JPEG previews', () => {
    expect(validScreenThumbnail(new Uint8Array([0xff, 0xd8, 0xff, 0xd9]))).toBe(true)
    expect(validScreenThumbnail(new Uint8Array(33 * 1024))).toBe(false)
    expect(validScreenThumbnail(new Uint8Array([1, 2, 3]))).toBe(false)
  })
})
