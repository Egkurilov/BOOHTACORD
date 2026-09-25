package recoverlastadministratoraccesspostgres

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"voice-platform/backend/internal/identity/recover_administrator"
	recoverpostgres "voice-platform/backend/internal/identity/recover_administrator/postgres"
)

func TestZeroAdministratorRecoveryWaitsForConcurrentPromotion(t *testing.T) {
	pool := newRecoveryPool(t)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	blockedID, memberID := uuid.NewString(), uuid.NewString()
	for _, fixture := range []struct {
		statement string
		id        string
	}{
		{`INSERT INTO users (id, login, display_name, password_hash, role, blocked_at) VALUES ($1, 'blockedowner', 'Owner', 'old-hash', 'ADMINISTRATOR', now())`, blockedID},
		{`INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'member', 'Member', 'member-hash', 'MEMBER')`, memberID},
	} {
		if _, err := pool.Exec(ctx, fixture.statement, fixture.id); err != nil {
			t.Fatal(err)
		}
	}
	promotion, err := pool.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer promotion.Rollback(ctx)
	if _, err := promotion.Exec(ctx, `SELECT pg_advisory_xact_lock(441903816)`); err != nil {
		t.Fatal(err)
	}
	if _, err := promotion.Exec(ctx, `UPDATE users SET role='ADMINISTRATOR' WHERE id=$1`, memberID); err != nil {
		t.Fatal(err)
	}
	result := make(chan error, 1)
	go func() {
		result <- recoverpostgres.New(recoverpostgres.NewPoolDatabase(pool)).RecoverLast(ctx, "blockedowner", "new-hash")
	}()
	select {
	case err := <-result:
		_ = promotion.Commit(ctx)
		t.Fatalf("zero-admin recovery finished before role change committed: %v", err)
	case <-time.After(750 * time.Millisecond):
	}
	if err := promotion.Commit(ctx); err != nil {
		t.Fatal(err)
	}
	if err := <-result; !errors.Is(err, recoveradministrator.ErrRecoveryUnavailable) {
		t.Fatalf("recovery after promotion = %v, want unavailable", err)
	}
	var hash, role string
	var blocked bool
	if err := pool.QueryRow(ctx, `SELECT password_hash, role, blocked_at IS NOT NULL FROM users WHERE id=$1`, blockedID).Scan(&hash, &role, &blocked); err != nil {
		t.Fatal(err)
	}
	if hash != "old-hash" || role != "ADMINISTRATOR" || !blocked {
		t.Fatalf("denied recovery changed hash=%t role=%q blocked=%t", hash != "old-hash", role, blocked)
	}
}
