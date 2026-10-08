import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
import { revokedLeaseSql } from './revocation_sql.mjs'

test('actual cached-ACL witness preserves the required revocation pair', () => {
  const id = '58bfae98-5284-412f-ba24-f2267593f864'
  assert.equal(revokedLeaseSql(id), `UPDATE voice_leases SET revoked_at=now(), revocation_reason='KICK' WHERE user_id='${id}' AND revoked_at IS NULL`)
  const migration = readFileSync(new URL('../../../backend/internal/database/migrate/migrations/0010_create_voice_leases.sql', import.meta.url), 'utf8')
  assert.ok(migration.includes('revoked_at IS NOT NULL AND revocation_reason IS NOT NULL'))
})

test('actual fixture rejects interpolated SQL', () => {
  assert.throws(() => revokedLeaseSql("bad'; DELETE FROM users; --"))
})
