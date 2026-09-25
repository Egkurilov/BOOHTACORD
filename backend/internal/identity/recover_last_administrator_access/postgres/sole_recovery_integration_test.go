package recoverlastadministratoraccesspostgres

import (
	"context"
	"testing"

	"github.com/google/uuid"
)

func TestSoleAdministratorRecoveryRevokesSessionAndMediaLease(t *testing.T) {
	pool := newRecoveryPool(t)
	ctx := context.Background()
	ownerID := uuid.NewString()
	if _, err := pool.Exec(ctx, `INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'owner', 'Owner', 'old-hash', 'ADMINISTRATOR')`, ownerID); err != nil {
		t.Fatal(err)
	}
	leaseID, sessionDigest := seedRecoveryAccess(t, pool, ownerID)
	if err := New(NewPoolDatabase(pool)).RecoverSoleActiveAdministrator(ctx, "owner", "new-hash"); err != nil {
		t.Fatal(err)
	}
	var hash, reason string
	var sessionRevoked, leaseRevoked bool
	var queued, audited int
	for _, check := range []struct {
		query string
		args  []any
		dest  []any
	}{
		{`SELECT password_hash FROM users WHERE id=$1`, []any{ownerID}, []any{&hash}},
		{`SELECT revoked_at IS NOT NULL FROM sessions WHERE token_digest=$1`, []any{sessionDigest[:]}, []any{&sessionRevoked}},
		{`SELECT revoked_at IS NOT NULL, revocation_reason FROM voice_leases WHERE id=$1`, []any{leaseID}, []any{&leaseRevoked, &reason}},
		{`SELECT count(*) FROM voice_sfu_revocations WHERE lease_id=$1`, []any{leaseID}, []any{&queued}},
		{`SELECT count(*) FROM audit_events WHERE event_type='LAST_ADMINISTRATOR_ACCESS_RECOVERED' AND target_user_id=$1`, []any{ownerID}, []any{&audited}},
	} {
		if err := pool.QueryRow(ctx, check.query, check.args...).Scan(check.dest...); err != nil {
			t.Fatal(err)
		}
	}
	if hash != "new-hash" || !sessionRevoked || !leaseRevoked || reason != "SESSION_REVOKED" || queued != 1 || audited != 1 {
		t.Fatalf("recovery hash_changed=%t session=%t lease=%t reason=%q queued=%d audited=%d", hash == "new-hash", sessionRevoked, leaseRevoked, reason, queued, audited)
	}
}
