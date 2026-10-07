import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const source = readFileSync(new URL('../../index.html', import.meta.url), 'utf8')
const head = source.slice(source.indexOf('<head>'), source.indexOf('</head>'))

function tags(attribute: 'name' | 'property', values: string[]) {
  const found = [...head.matchAll(/<meta\b([^>]*)>/g)]
  for (const value of values) {
    const tag = found.find(([, raw]) => new RegExp(attribute + '="' + value + '"').test(raw))
    expect(tag, 'missing ' + attribute + '=' + value).toBeDefined()
    expect(tag?.[1]).toMatch(/content="[^"]+"/)
  }
}

describe('static social preview head', () => {
  it('contains complete metadata before JavaScript and the approved copy', () => {
    tags('name', ['description', 'twitter:card', 'twitter:title', 'twitter:description', 'twitter:image', 'twitter:image:alt', 'theme-color'])
    tags('property', ['og:type', 'og:site_name', 'og:title', 'og:description', 'og:url', 'og:locale', 'og:image', 'og:image:width', 'og:image:height', 'og:image:type', 'og:image:alt'])
    expect(head).toMatch(/<link\b[^>]*rel="canonical"[^>]*href="__SOCIAL_ORIGIN__\//)
    expect(head).toContain('content="BOOHTACORD — голос и чаты вашей гильдии"')
    expect(head).toContain('content="Присоединяйтесь к BOOHTACORD: общайтесь в чатах, заходите в голосовые каналы и делитесь экраном с участниками своей гильдии."')
    expect(head).toContain('__SOCIAL_ORIGIN__/social/boohtacord-og-1200x630.png')
    expect(head).toContain('property="og:image:width" content="1200"')
    expect(head).toContain('property="og:image:height" content="630"')
    expect(head).toContain('property="og:image:type" content="image/png"')
    expect(source.indexOf('</head>')).toBeLessThan(source.indexOf('<script type="module"'))
  })

  it('preserves the application entry and existing title/favicon', () => {
    expect(source).toContain('<title>BOOHTACORD</title>')
    expect(source).toContain('href="/favicon.png"')
    expect(source).toContain('<div id="app"></div>')
    expect(source).toContain('src="/src/main.ts"')
  })
})
