import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const component = readFileSync(new URL('./AudioSettings.vue', import.meta.url), 'utf8')
const styles = readFileSync(new URL('../design/design_v2_audio.css', import.meta.url), 'utf8')

describe('Design V2 audio settings', () => {
  it('keeps device selection, local checks, activation, and processing under their existing stores', () => {
    for (const value of ['choose(\'audioinput\'', 'choose(\'audiooutput\'', 'AudioDeviceCheck', "emit('setActivation'", "emit('setProcessing'"]) expect(component).toContain(value)
  })

  it('matches the desktop and mobile device panel sizes from R10/R11', () => {
    expect(styles).toContain('height: 282px;')
    expect(styles).toContain('height: 402px;')
    expect(styles).toContain('grid-template-columns: repeat(2, minmax(0, 1fr));')
  })
})
