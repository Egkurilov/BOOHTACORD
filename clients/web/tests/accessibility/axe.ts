import { expect, type Page } from '@playwright/test'
import { fileURLToPath } from 'node:url'

const axeScript = fileURLToPath(new URL('../../node_modules/axe-core/axe.min.js', import.meta.url))

export async function expectAxeClear(page: Page, context = 'body'): Promise<void> {
  await page.addScriptTag({ path: axeScript })
  const violations = await page.evaluate(async (selector) => {
    const axe = (window as any).axe
    const result = await axe.run(document.querySelector(selector), {
      runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'] },
    })
    return result.violations.map((violation: any) => ({
      id: violation.id,
      help: violation.help,
      nodes: violation.nodes.map((node: any) => ({ target: node.target, summary: node.failureSummary })),
    }))
  }, context)
  expect(violations, JSON.stringify(violations, null, 2)).toEqual([])
}
