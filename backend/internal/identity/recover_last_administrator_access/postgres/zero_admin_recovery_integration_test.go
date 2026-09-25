package recoverlastadministratoraccesspostgres

import (
	"context"
	"testing"

	"github.com/google/uuid"
	recoverpostgres "voice-platform/backend/internal/identity/recover_administrator/postgres"
)

func TestZeroAdministratorRecoveryUnblocksAndRevokesAccess(t *testing.T) {
	pool := newRecoveryPool(t)
	ctx := context.Background()
	ownerID := uuid.NewString()
	if _, err := pool.Exec(ctx, `INSERT INTO users (id, login, display_name, password_hash, role, blocked_at) VALUES ($1, 'blockedowner', 'Owner', 'old-hash', 'ADMINISTRATOR', now())`, ownerID); err != nil {
		t.Fatal(err)
	}
	leaseID, sessionDigest := seedRecoveryAccess(t, pool, ownerID)
	if err := recoverpostgres.New(recoverpostgres.NewPoolDatabase(pool)).RecoverLast(ctx, "blockedowner", "new-hash"); err != nil {
		t.Fatal(err)
	}
	var hash, role, reason string
	var blocked, sessionRevoked, leaseRevoked bool
	var queued, audited int
	for _, check := range []struct {
		query string
		args  []any
		dest  []any
	}{
		{`SELECT password_hash, role, blocked_at IS NOT NULL FROM users WHERE id=$1`, []any{ownerID}, []any{&hash, &role, &blocked}},
		{`SELECT revoked_at IS NOT NULL FROM sessions WHERE token_digest=$1`, []any{sessionDigest[:]}, []any{&sessionRevoked}},
		{`SELECT revoked_at IS NOT NULL, revocation_reason FROM voice_leases WHERE id=$1`, []any{leaseID}, []any{&leaseRevoked, &reason}},
		{`SELECT count(*) FROM voice_sfu_revocations WHERE lease_id=$1`, []any{leaseID}, []any{&queued}},
		{`SELECT count(*) FROM audit_events WHERE event_type='ADMINISTRATOR_RECOVERED' AND target_user_id=$1`, []any{ownerID}, []any{&audited}},
	} {
		if err := pool.QueryRow(ctx, check.query, check.args...).Scan(check.dest...); err != nil {
			t.Fatal(err)
		}
	}
	if hash != "new-hash" || role != "ADMINISTRATOR" || blocked || !sessionRevoked || !leaseRevoked || reason != "SESSION_REVOKED" || queued != 1 || audited != 1 {
		t.Fatalf("recovery hash_changed=%t role=%q blocked=%t session=%t lease=%t reason=%q queued=%d audited=%d", hash == "new-hash", role, blocked, sessionRevoked, leaseRevoked, reason, queued, audited)
	}
}
