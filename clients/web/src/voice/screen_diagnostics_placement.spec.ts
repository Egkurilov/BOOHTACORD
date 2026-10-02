import { describe, expect, it } from 'vitest'

import { placeScreenDiagnostics } from './screen_diagnostics_placement'

describe('screen diagnostics popover placement', () => {
  it('opens above a summary near the bottom edge when the panel will not fit below', () => {
    expect(placeScreenDiagnostics({
      summaryLeft: 700,
      summaryRight: 780,
      summaryTop: 700,
      summaryBottom: 736,
      panelHeight: 360,
      panelWidth: 288,
      viewportWidth: 800,
      viewportHeight: 800,
    })).toMatchObject({ placement: 'above', maxHeight: 676 })
  })

  it('keeps the panel below when it fits and constrains it to available viewport space', () => {
    expect(placeScreenDiagnostics({
      summaryLeft: 40,
      summaryRight: 120,
      summaryTop: 40,
      summaryBottom: 76,
      panelHeight: 500,
      panelWidth: 288,
      viewportWidth: 800,
      viewportHeight: 800,
    })).toMatchObject({ placement: 'below', maxHeight: 700 })
  })

  it('uses the roomier side and clips panel height when neither side fits', () => {
    expect(placeScreenDiagnostics({
      summaryLeft: 130,
      summaryRight: 210,
      summaryTop: 260,
      summaryBottom: 296,
      panelHeight: 500,
      panelWidth: 288,
      viewportWidth: 360,
      viewportHeight: 360,
    })).toMatchObject({ placement: 'above', maxHeight: 236 })
  })

  it('returns fixed coordinates that keep the popover inside a narrow viewport', () => {
    const result = placeScreenDiagnostics({
      summaryLeft: 304,
      summaryRight: 344,
      summaryTop: 700,
      summaryBottom: 736,
      panelHeight: 500,
      panelWidth: 288,
      viewportWidth: 360,
      viewportHeight: 800,
    })

    expect(result).toMatchObject({ placement: 'above', maxHeight: 676 })
    expect(result.left).toBe(56)
    expect(result.top).toBe(192)
    expect(result.left).toBeGreaterThanOrEqual(16)
    expect(result.left + 288).toBeLessThanOrEqual(344)
    expect(result.top).toBeGreaterThanOrEqual(16)
    expect(result.top + 500).toBeLessThanOrEqual(784)
  })
})
