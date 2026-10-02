import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

import { evaluateUpdate } from './evaluator'
import type { EvaluationEnvironment, LocalIdentity, UpdatePolicy } from './types'

type Fixture = { name: string; local: LocalIdentity | null; environment: EvaluationEnvironment; policy: UpdatePolicy; want: string }
const fixtures = JSON.parse(
  readFileSync(new URL('../../../../contracts/client-update-evaluator.fixtures.json', import.meta.url), 'utf8'),
) as { cases: Fixture[] }

describe('client update evaluator contract', () => {
  for (const fixture of fixtures.cases) {
    it(fixture.name, () => expect(evaluateUpdate(fixture.local, fixture.policy, fixture.environment)).toBe(fixture.want))
  }
})
