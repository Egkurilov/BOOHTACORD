import { readFileSync } from 'node:fs'

const root = 'C:/Users/egkur/Downloads/BOOHTACORD_DESIGN_V2_LIVE_HTML_SOURCE_2026-10-03/BOOHTACORD_DESIGN_V2_HTML/screens'
for (const id of process.argv.slice(2)) {
  const html = readFileSync(`${root}/${id}.html`, 'utf8')
  const classes = [...html.matchAll(/class="([^"]+)"/g)].flatMap((match) => match[1].split(/\s+/))
  console.log(id, [...new Set(classes.filter((name) => /dialog|modal|viewer|preview|reply|mention|component/i.test(name)))].join(' '))
}
