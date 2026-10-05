import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
export function owned(role, ...command) {
  const owner = process.env.QA_DB_OWNER
  assert.match(owner, /^qa-client-[a-f0-9]{16}$/)
  assert.ok(['db', 'sfu'].includes(role))
  const name = owner+'-'+role
  const label = execFileSync('docker', ['inspect', name, '--format', '{{index .Config.Labels "boohtacord.qa.owner"}}'], { encoding: 'utf8' }).trim()
  assert.equal(label, owner, 'Foreign fixture service')
  return execFileSync('docker', command.map(value => value === '$owned' ? name : value), { stdio: ['ignore', 'pipe', 'pipe'] })
}
