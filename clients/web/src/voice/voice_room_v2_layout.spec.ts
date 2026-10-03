import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const source = (file: string) => readFileSync(new URL(file, import.meta.url), 'utf8')

describe('connected voice room v2', () => {
  it('keeps live connection actions while presenting the shared room controls', () => {
    const pane = source('../conversation/ConversationPane.vue')
    const connected = source('./VoiceRoomConnected.vue')
    const controls = source('./VoiceRoomControls.vue')
    expect(pane).toContain('<VoiceRoomConnected')
    expect(connected).toContain('<VoiceParticipantVolumes')
    expect(connected).toContain('watchScreen')
    expect(controls).toContain('toggleMicrophone')
    expect(controls).toContain('toggleDeafen')
    expect(controls).toContain('startScreen')
    expect(controls).toContain("emit('leave')")
  })
})
