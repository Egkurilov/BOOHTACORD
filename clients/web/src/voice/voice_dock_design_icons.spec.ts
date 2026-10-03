import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const dock = readFileSync(new URL('./VoiceDock.vue', import.meta.url), 'utf8')

describe('Design V2 voice dock icons', () => {
  it('uses the handoff microphone outline while keeping the existing action', () => {
    expect(dock).toContain('<rect x="9" y="2" width="6" height="12" rx="3"/>')
    expect(dock).toContain('M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8')
    expect(dock).toContain("@click=\"emit('toggleMicrophone')\"")
  })
})
