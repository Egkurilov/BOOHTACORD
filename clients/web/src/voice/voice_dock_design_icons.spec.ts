import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const dock = readFileSync(new URL('./VoiceDock.vue', import.meta.url), 'utf8')

describe('Design V2 voice dock icons', () => {
  it('uses the handoff microphone outline while keeping the existing action', () => {
    expect(dock).toContain('<rect x="9" y="2" width="6" height="12" rx="3"/>')
    expect(dock).toContain('M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8')
    expect(dock).toContain("@click=\"emit('toggleMicrophone')\"")
  })

  it('uses the handoff monitor icon while retaining screen share events', () => {
    expect(dock).toContain('<rect v-else x="2" y="3" width="20" height="14" rx="2"/>')
    expect(dock).toContain('<path v-if="screenShareState !== \'SHARING\'" d="M8 21h8M12 17v4"/>')
    expect(dock).toContain("emit('stopScreen') : emit('startScreen')")
  })

  it('uses the same headphones outline for the header and deafen control', () => {
    expect(dock.match(/M3 14v-3a9 9 0 0 1 18 0v3/g)).toHaveLength(2)
    expect(dock).toContain("@click=\"emit('toggleDeafen')\"")
  })
})
