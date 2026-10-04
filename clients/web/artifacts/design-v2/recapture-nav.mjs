import { execFileSync, spawn } from 'node:child_process'
import { writeFileSync } from 'node:fs'
import { join } from 'node:path'

const root = process.env.DESIGN_V2_ARTIFACT_ROOT
const scene = process.env.DESIGN_V2_SCENE_PNG
if (!root || !scene) throw new Error('DESIGN_V2_ARTIFACT_ROOT and DESIGN_V2_SCENE_PNG are required')
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', '4180'], { stdio: 'ignore' })
process.on('exit', () => server.kill())
server.unref()
const url = 'http://127.0.0.1:4180/'
for (let attempt = 0; attempt < 50; attempt += 1) {
  try { if ((await fetch(url)).ok) break } catch { /* Vite is starting. */ }
  await new Promise((resolve) => setTimeout(resolve, 100))
}
try {
  const destination = join(root, 'design-v2-all-screens')
  const result = execFileSync(process.execPath, ['artifacts/design-v2/dom-probe.mjs', 'nav', '390', '844'], {
    encoding: 'utf8', env: { ...process.env, DESIGN_V2_REFERENCE_FIXTURE: '1', DESIGN_V2_LIVE_STATE: '1',
      DESIGN_V2_VERIFY_INTERACTIONS: '1', DESIGN_V2_URL: url, DESIGN_V2_SCENE_PNG: scene,
      DESIGN_V2_SCREENSHOT: join(destination, 'R14-actual.png') },
  })
  writeFileSync(join(destination, 'R14-dom.json'), result)
  console.log('Captured R14')
} finally { server.kill() }
