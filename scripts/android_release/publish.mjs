export * from '../../tools/release/android/publish.mjs'
import { spawnSync } from 'node:child_process'
import { fileURLToPath, pathToFileURL } from 'node:url'
import path from 'node:path'
if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const result = spawnSync(process.execPath, [fileURLToPath(new URL('../../tools/release/android/publish.mjs', import.meta.url)), ...process.argv.slice(2)], { stdio: 'inherit' })
  process.exitCode = result.status ?? 1
}
