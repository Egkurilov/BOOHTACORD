import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const component = readFileSync(new URL('./AudioSettings.vue', import.meta.url), 'utf8')
const deviceCheck = readFileSync(new URL('./AudioDeviceCheck.vue', import.meta.url), 'utf8')
const styles = readFileSync(new URL('../design/design_v2_audio.css', import.meta.url), 'utf8')
const presentation = readFileSync(new URL('../design/design_v2_audio_presentation.css', import.meta.url), 'utf8')
const workspace = readFileSync(new URL('../workspace/WorkspaceMain.vue', import.meta.url), 'utf8')

describe('Design V2 audio settings', () => {
  it('keeps device selection, local checks, activation, and processing under their existing stores', () => {
    for (const value of ['choose(\'audioinput\'', 'choose(\'audiooutput\'', 'AudioDeviceCheck', "emit('setActivation'", "emit('setProcessing'"]) expect(component).toContain(value)
  })

  it('matches the desktop and mobile device panel sizes from R10/R11', () => {
    expect(styles).toContain('height: 282px;')
    expect(styles).toContain('height: 402px;')
    expect(styles).toContain('grid-template-columns: repeat(2, minmax(0, 1fr));')
  })

  it('shows a settings toolbar, segmented activation and visible processing controls', () => {
    expect(workspace).toContain('class="settings-workspace-header"')
    expect(component).toContain('class="audio-activation-selector"')
    expect(component).toContain('class="audio-processing-row"')
    expect(presentation).toContain('.audio-settings-panel { display: contents;')
  })

  it('retains the local microphone check lifecycle behind the V2 level meter', () => {
    expect(deviceCheck).toContain('startMicrophoneCheck(')
    expect(deviceCheck).toContain('onBeforeUnmount(stopInput)')
    expect(deviceCheck).toContain('watch(() => props.inputId, stopInput)')
    expect(deviceCheck).toContain('class="audio-level-meter"')
  })

  it('uses the handoff speaker icon for the output check', () => {
    expect(deviceCheck).toContain('M15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14')
  })
})
