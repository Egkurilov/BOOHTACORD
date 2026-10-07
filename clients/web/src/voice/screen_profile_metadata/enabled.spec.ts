import { describe, expect, it, vi } from 'vitest'
import { screenDescriptorMetadataEnabled } from './enabled'

describe('screen descriptor metadata rollout', () => {
  it('is enabled by default and can be disabled without changing simulcast', () => {
    vi.stubEnv('VITE_SCREEN_SHARE_DESCRIPTOR_V1', '')
    expect(screenDescriptorMetadataEnabled()).toBe(true)
    vi.stubEnv('VITE_SCREEN_SHARE_DESCRIPTOR_V1', 'false')
    expect(screenDescriptorMetadataEnabled()).toBe(false)
  })
})
