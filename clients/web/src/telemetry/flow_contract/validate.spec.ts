import { expect, it } from 'vitest'
import fixtures from './fixtures'
import { validField } from './validate'
it('matches the shared privacy and boundary fixtures', () => {
 for (const row of fixtures) expect(validField(row.key,row.value),row.key).toBe(row.valid)
})

