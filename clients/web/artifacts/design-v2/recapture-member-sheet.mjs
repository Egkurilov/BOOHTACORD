import { execFileSync, spawn } from 'node:child_process'
import { mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const root = process.env.DESIGN_V2_ARTIFACT_ROOT
const scene = process.env.DESIGN_V2_SCENE_PNG
if (!root || !scene) throw new Error('DESIGN_V2_ARTIFACT_ROOT and DESIGN_V2_SCENE_PNG are required')
const destination = join(root, 'design-v2-member-mobile')
mkdirSync(destination, { recursive: true })
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', '4181'], { stdio: 'ignore' })
process.on('exit', () => server.kill())
server.unref()
const url = 'http://127.0.0.1:4181/'
for (let attempt = 0; attempt < 50; attempt += 1) {
  try { if ((await fetch(url)).ok) break } catch { /* Vite is starting. */ }
  await new Promise((resolve) => setTimeout(resolve, 100))
}
try {
  execFileSync(process.execPath, ['artifacts/design-v2/member-sheet-probe.mjs'], {
    encoding: 'utf8', env: { ...process.env, DESIGN_V2_ARTIFACT_DIR: destination },
  })
  const folder = join(root, 'design-v2-all-screens')
  const result = execFileSync(process.execPath, ['artifacts/design-v2/dom-probe.mjs', 'member-popover', '1440', '900'], {
    encoding: 'utf8', env: { ...process.env, DESIGN_V2_REFERENCE_FIXTURE: '1', DESIGN_V2_LIVE_STATE: '1',
      DESIGN_V2_VERIFY_INTERACTIONS: '1', DESIGN_V2_URL: url, DESIGN_V2_SCENE_PNG: scene,
      DESIGN_V2_SCREENSHOT: join(folder, 'R18-actual.png') },
  })
  writeFileSync(join(folder, 'R18-dom.json'), result)
  console.log('Captured mobile member sheet and R18')
} finally { server.kill() }
