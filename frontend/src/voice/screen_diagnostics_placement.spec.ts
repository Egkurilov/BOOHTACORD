import { describe, expect, it } from 'vitest'

import { placeScreenDiagnostics } from './screen_diagnostics_placement'

describe('screen diagnostics popover placement', () => {
  it('opens above a summary near the bottom edge when the panel will not fit below', () => {
    expect(placeScreenDiagnostics({
      summaryTop: 700,
      summaryBottom: 736,
      panelHeight: 360,
      viewportHeight: 800,
    })).toEqual({ placement: 'above', maxHeight: 676 })
  })

  it('keeps the panel below when it fits and constrains it to available viewport space', () => {
    expect(placeScreenDiagnostics({
      summaryTop: 40,
      summaryBottom: 76,
      panelHeight: 500,
      viewportHeight: 800,
    })).toEqual({ placement: 'below', maxHeight: 700 })
  })

  it('uses the roomier side and clips panel height when neither side fits', () => {
    expect(placeScreenDiagnostics({
      summaryTop: 260,
      summaryBottom: 296,
      panelHeight: 500,
      viewportHeight: 360,
    })).toEqual({ placement: 'above', maxHeight: 236 })
  })
})
