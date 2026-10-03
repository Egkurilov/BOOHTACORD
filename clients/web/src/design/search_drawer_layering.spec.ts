import { readFileSync } from 'node:fs'
import postcss from 'postcss'
import { describe, expect, it } from 'vitest'

const stylesheet = readFileSync(new URL('../style.css', import.meta.url), 'utf8')
const tokens = readFileSync(new URL('./tokens.css', import.meta.url), 'utf8')
const imports = [...stylesheet.matchAll(/@import '\.\/design\/([^']+\.css)'/g)].map((match) => match[1])

function mediaMatches(params: string, width: number): boolean {
  const min = params.match(/min-width:\s*(\d+)px/)
  const max = params.match(/max-width:\s*(\d+)px/)
  return (!min || width >= Number(min[1])) && (!max || width <= Number(max[1]))
}

function zIndexAt(selector: string, width: number): number | null {
  let value: number | null = null
  for (const file of imports) {
    const root = postcss.parse(readFileSync(new URL(file, import.meta.url), 'utf8'))
    root.walkRules((rule) => {
      if (!rule.selectors.includes(selector)) return
      const parent = rule.parent
      if (parent?.type === 'atrule' && parent.name === 'media' && !mediaMatches(parent.params, width)) return
      rule.walkDecls('z-index', (declaration) => {
        const token = declaration.value.match(/^var\(--gc-([\w-]+)\)$/)?.[1]
        const resolved = token
          ? tokens.match(new RegExp(`--gc-${token}:\\s*(\\d+);`))?.[1]
          : declaration.value
        value = resolved === undefined ? null : Number(resolved)
      })
    })
  }
  return value
}

describe('global search drawer layering', () => {
  it.each([320, 883, 1024, 1279])('keeps the search drawer above its modal scrim at %i CSS px', (width) => {
    const search = zIndexAt('.search-aside', width)
    const scrim = zIndexAt('.drawer-scrim', width)
    expect(search).not.toBeNull()
    expect(scrim).not.toBeNull()
    expect(search!).toBeGreaterThan(scrim!)
  })
})
