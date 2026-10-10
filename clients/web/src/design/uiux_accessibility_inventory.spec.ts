import { existsSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'

type AccessibilityScenario = {
  id: string
  controlsAndActions: string[]
  web: { status: string; testFiles: string[]; manualAssistiveTech: string }
  flutter: { status: string; testFiles: string[]; manualAssistiveTech: string }
}

type AccessibilityInventory = {
  scenarios: AccessibilityScenario[]
  contrast: { status: string; evidence: string; testFiles: string[] }
  touchTargets: { productMinimumCssOrLogicalPx: number; automatedEvidence: string[]; exceptionsNote: string }
  manualAcceptance: Record<string, string>
}

const repoRoot = resolve(fileURLToPath(new URL('../../../..', import.meta.url)))
const inventoryPath = new URL('../../tests/accessibility/uiux_2026_inventory.json', import.meta.url)

describe('UIUX-2026 accessibility inventory', () => {
  it('maps seven critical flows to existing Web and Flutter evidence without upgrading manual checks', () => {
    const inventory = JSON.parse(readFileSync(inventoryPath, 'utf8')) as AccessibilityInventory
    const expected = ['guild-navigation', 'chat-dm', 'admin', 'settings', 'dialogs', 'voice', 'stream']
    const allowedStatuses = ['PASS_SCOPED', 'PARTIAL', 'NOT_RUN']

    expect(inventory.scenarios.map(({ id }) => id)).toEqual(expected)
    for (const scenario of inventory.scenarios) {
      expect(scenario.controlsAndActions.length, `${scenario.id} controls`).toBeGreaterThan(0)
      for (const client of [scenario.web, scenario.flutter]) {
        expect(allowedStatuses, `${scenario.id} status`).toContain(client.status)
        expect(client.testFiles.length, `${scenario.id} test mapping`).toBeGreaterThan(0)
        expect(client.testFiles.every(path => existsSync(resolve(repoRoot, path))), `${scenario.id} evidence paths`).toBe(true)
        expect(client.manualAssistiveTech, `${scenario.id} manual screen-reader status`).toBe('NOT_RUN')
      }
    }

    expect(inventory.contrast.status).toBe('PASS_SAMPLED')
    expect(inventory.contrast.testFiles.every(path => existsSync(resolve(repoRoot, path)))).toBe(true)
    expect(existsSync(resolve(repoRoot, inventory.contrast.evidence))).toBe(true)
    expect(inventory.touchTargets.productMinimumCssOrLogicalPx).toBe(44)
    expect(inventory.touchTargets.automatedEvidence.every(path => existsSync(resolve(repoRoot, path)))).toBe(true)
    expect(inventory.touchTargets.exceptionsNote).toContain('WCAG 2.2 AA')
    expect(Object.values(inventory.manualAcceptance).every(status => status === 'NOT_RUN')).toBe(true)
    expect(existsSync(resolve(repoRoot, 'docs/design/UIUX_2026_ACCESSIBILITY.md'))).toBe(true)
  })
})
