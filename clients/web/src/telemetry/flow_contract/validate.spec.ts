import { expect, it } from 'vitest'
import fixtures from '../../../../../contracts/telemetry-flow-v1.fixtures.json'
import { validField } from './validate'
it('matches the shared privacy and boundary fixtures', () => {
 for (const row of fixtures) expect(validField(row.key,row.value),row.key).toBe(row.valid)
})

