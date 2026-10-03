import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

type Comparison = { element: string; missing: boolean; geometryEqual: boolean; styleEqual: boolean; differences: Array<{ property: string; reference: string | null; actual: string | null }> }
type Review = { screens: Array<{ id: string; status: string; reason?: string; comparisons: Comparison[] }> }

const review = JSON.parse(readFileSync(new URL('../../artifacts/design-v2/style-review.json', import.meta.url), 'utf8')) as Review

describe('Design V2 computed-style fidelity review', () => {
  it('records every handoff state and explicitly classifies the component catalog', () => {
    expect(review.screens.map(({ id }) => id)).toEqual(Array.from({ length: 30 }, (_, index) => `R${String(index + 1).padStart(2, '0')}`))
    const catalog = review.screens.find(({ id }) => id === 'R15')
    expect(catalog?.status).toBe('REFERENCE_ONLY')
    expect(catalog?.reason).toContain('no application route')
  })

  it('compares painted production components to the live HTML values with no remaining differences', () => {
    const measurable = review.screens.filter(({ id }) => id !== 'R15')
    expect(measurable.every(({ status, comparisons }) => status === 'MATCH' && comparisons.length > 0 && comparisons.every(({ missing, geometryEqual, styleEqual }) => !missing && geometryEqual && styleEqual))).toBe(true)
    const differences = measurable.flatMap(({ id, comparisons }) => comparisons.flatMap(({ element, differences: values }) => values.map((value) => ({ id, element, ...value }))))
    expect(differences).toEqual([])
  })
})
