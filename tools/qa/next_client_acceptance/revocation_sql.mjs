import assert from 'node:assert/strict'

export function revokedLeaseSql(accountId) {
  assert.match(accountId, /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i)
  return `UPDATE voice_leases SET revoked_at=now(), revocation_reason='KICK' WHERE user_id='${accountId}' AND revoked_at IS NULL`
}
