import { execFileSync, spawn } from 'node:child_process'
import { writeFileSync } from 'node:fs'
import { join } from 'node:path'

const root = process.env.DESIGN_V2_ARTIFACT_ROOT
const scene = process.env.DESIGN_V2_SCENE_PNG
if (!root || !scene) throw new Error('DESIGN_V2_ARTIFACT_ROOT and DESIGN_V2_SCENE_PNG are required')
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', '4179'], { stdio: 'ignore' })
process.on('exit', () => server.kill())
server.unref()
const url = 'http://127.0.0.1:4179/'
for (let attempt = 0; attempt < 50; attempt += 1) {
  try { if ((await fetch(url)).ok) break } catch { /* Vite is starting. */ }
  await new Promise((resolve) => setTimeout(resolve, 100))
}
try {
  for (const [id, state, width, height, directory] of [
    ['R01', 'chat', 1440, 900, 'design-v2-r01-r03'],
    ['R02', 'chat', 390, 844, 'design-v2-r01-r03'],
    ['R03', 'chat', 1024, 768, 'design-v2-r01-r03'],
    ['R28', 'dm', 1440, 900, 'design-v2-all-screens'],
  ]) {
    const destination = join(root, directory)
    const result = execFileSync(process.execPath, ['artifacts/design-v2/dom-probe.mjs', state, String(width), String(height)], {
      encoding: 'utf8', env: { ...process.env, DESIGN_V2_REFERENCE_FIXTURE: '1', DESIGN_V2_LIVE_STATE: '1',
        DESIGN_V2_VERIFY_INTERACTIONS: '1', DESIGN_V2_URL: url, DESIGN_V2_SCENE_PNG: scene,
        DESIGN_V2_SCREENSHOT: join(destination, `${id}-actual.png`) },
    })
    writeFileSync(join(destination, `${id}-dom.json`), result)
    console.log(`Captured ${id}`)
  }
} finally { server.kill() }
