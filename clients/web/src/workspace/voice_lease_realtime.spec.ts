import { describe, expect, it, vi } from 'vitest'

import { applyVoiceLeaseRevocation } from './voice_lease_realtime'

describe('targeted voice lease revocation', () => {
  it('does not end a healthy call for a different lease', async () => {
    const voice = { active: { leaseId: 'lease-current' }, revokeLease: vi.fn(async () => true) }
    const navigation = { clearActiveVoice: vi.fn() }
    await applyVoiceLeaseRevocation(voice, navigation, 'lease-other', 'KICK')
    expect(voice.revokeLease).not.toHaveBeenCalled()
    expect(navigation.clearActiveVoice).not.toHaveBeenCalled()
  })

  it('ends only the matching lease, keeps its reason and clears connected navigation', async () => {
    const voice = { active: { leaseId: 'lease-current' }, revokeLease: vi.fn(async () => true) }
    const navigation = { clearActiveVoice: vi.fn() }
    await applyVoiceLeaseRevocation(voice, navigation, 'lease-current', 'CHANNEL_CLOSED')
    expect(voice.revokeLease).toHaveBeenCalledWith('lease-current', 'CHANNEL_CLOSED')
    expect(navigation.clearActiveVoice).toHaveBeenCalledOnce()
  })

  it('passes a hint through during admission for a future exact lease match', async () => {
    const voice = { active: null, state: 'JOINING', revokeLease: vi.fn(async () => false) }
    const navigation = { clearActiveVoice: vi.fn() }
    await applyVoiceLeaseRevocation(voice, navigation, 'lease-pending', 'KICK')
    expect(voice.revokeLease).toHaveBeenCalledWith('lease-pending', 'KICK')
    expect(navigation.clearActiveVoice).not.toHaveBeenCalled()
  })
})
