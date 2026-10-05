import { spawn } from 'node:child_process'
import { once } from 'node:events'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import assert from 'node:assert/strict'
import test from 'node:test'

test('custom audio fixture uses the Vite HTML pipeline', { timeout: 30000 }, async () => {
  const root = fileURLToPath(new URL('../../../', import.meta.url))
  const child = spawn(process.execPath, [resolve(root, 'tools/audio/browser_runner.mjs')], {
    cwd: root, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
  })
  const exited = once(child, 'exit')
  try {
    await new Promise((ready, reject) => {
      child.on('error', reject)
      child.on('exit', code => reject(new Error(`fixture exited: ${code}`)))
      child.stdout.on('data', data => {
        if (String(data).includes('browser fixture ready')) ready()
      })
      child.stderr.resume()
    })
    const response = await fetch('http://127.0.0.1:4800/tests/audio/fixture.html', {
      signal: AbortSignal.timeout(15000),
    })
    assert.equal(response.status, 200)
    assert.match(response.headers.get('content-type'), /text\/html/)
    assert.match(response.headers.get('content-security-policy'), /script-src 'self'/)
    const html = await response.text()
    assert.match(html, /src="\/@vite\/client"/)
    for (const fixture of ['fixture', 'livekit_pair_fixture', 'microphone_join_fixture', 'audio_input_fixture']) {
      assert.match(html, new RegExp(`/tests/audio/${fixture}\\.ts`))
    }
  } finally {
    if (child.exitCode === null) child.kill('SIGTERM')
    await exited
  }
})
